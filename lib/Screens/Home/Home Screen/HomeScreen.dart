import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guideme/Models/Place.dart';
import 'package:guideme/Screens/Home/Home%20Screen/GovernoratePlacesScreen.dart';
import 'package:guideme/Screens/Place%20Details/placedetails.dart';
import 'package:guideme/Services/firestore_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/AppLocalizations.dart';
import '../../../core/AppState.dart';
import '../NearbyTouristSitesScreen.dart';
import '../searchscreen.dart';
import 'MustVisitSpots.dart';
import 'hidden_gems.dart';
import 'recents_section.dart';
import 'recommendations_section.dart';

// MessageOverlay widget for styled messages
class _MessageOverlay extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onDismiss;

  const _MessageOverlay({
    required this.message,
    required this.isError,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isError ? Colors.red.withOpacity(0.9) : Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  final PageController _pageController = PageController(viewportFraction: 0.9);
  late final ScrollController _fallbackScrollController;
  int _currentIndex = 0;
  Timer? _timer;
  Set<String> _savedPlaces = {};
  List<Place> _favoritePlaces = [];
  late AnimationController _animationController;
  static const String googleApiKey = 'AIzaSyD3iQPOazh9GfAOl44Y9kDHDJ0zyNqARSA';
  final GoogleMapsPlaces placesApi = GoogleMapsPlaces(apiKey: googleApiKey);
  final Key _mustVisitSpotsKey = UniqueKey();
  final Key _hiddenGemsKey = UniqueKey();
  Position? _userLocation;
  final Map<String, List<Place>> _cachedPlaces = {};
  List<Map<String, dynamic>> _governorates = [];
  Future<List<Place>>? _topRatedFuture;
  FirestoreService? _firestoreService;
  bool _isDataInitialized = false;
  OverlayEntry? _overlayEntry;

  List<Place> _recommendedPlaces = [];
  List<String> _recommendationReasons = [];
  bool _isLoadingRecommendations = false;
  bool _hasAttemptedRecommendations = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _fallbackScrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestoreService = FirestoreService(userId: user.uid);
      _migrateSharedPreferencesToFirestore();
    }
    _startAutoScroll();
    _getUserLocation();
    _fallbackScrollController.addListener(_scrollListener);
    if (!_isDataInitialized) {
      _initializeGovernorates();
      _initializeData();
      _isDataInitialized = true;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    _animationController.dispose();
    _fallbackScrollController.removeListener(_scrollListener);
    _fallbackScrollController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showMessageOverlay(String message, {bool isError = true}) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: 16,
        right: 16,
        child: _MessageOverlay(
          message: message,
          isError: isError,
          onDismiss: () {
            _overlayEntry?.remove();
            _overlayEntry = null;
          },
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    Timer(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  Future<void> _initializeData() async {
    await _loadSavedPlaces();
    if (_firestoreService != null) {
      await _fetchRecommendations();
    }
  }

  Future<void> _migrateSharedPreferencesToFirestore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPlaceIds = prefs.getStringList('saved_places')?.toSet() ?? {};
      if (savedPlaceIds.isEmpty || _firestoreService == null) return;

      for (final placeId in savedPlaceIds) {
        final place = await _fetchPlaceById(placeId);
        if (place != null) {
          await _firestoreService!.saveFavoritePlace(place);
        }
      }
      await prefs.remove('saved_places');
    } catch (e) {
      _showMessageOverlay('Error migrating saved places: $e');
    }
  }

  Future<Place?> _fetchPlaceById(String placeId) async {
    try {
      final response = await placesApi.getDetailsByPlaceId(placeId);
      if (response.isOkay && response.result.geometry?.location != null) {
        return Place(
          id: response.result.placeId,
          name: response.result.name,
          description: response.result.vicinity ?? 'No description available',
          imageUrl: response.result.photos.isNotEmpty == true
              ? _getPhotoUrl(response.result.photos.first.photoReference)
              : 'https://via.placeholder.com/400',
          latitude: response.result.geometry!.location.lat,
          longitude: response.result.geometry!.location.lng,
          category: response.result.types.isNotEmpty == true
              ? response.result.types.first
              : 'tourist_attraction',
          rating: response.result.rating?.toDouble() ?? 0.0,
          constructionHistory: 'Unknown',
          era: 'Unknown',
          builder: 'Unknown',
          audioUrl: '',
          indoorMap: [],
          routes: {},
          imageUrls: [],
        );
      }
      return null;
    } catch (e) {
      _showMessageOverlay('Error fetching place $placeId: $e');
      return null;
    }
  }

  Future<List<Place>> _fetchTopRatedPlaces() async {
    if (_userLocation == null) {
      return _getFallbackPlaces();
    }
    try {
      final response = await placesApi.searchNearbyWithRadius(
        Location(lat: _userLocation!.latitude, lng: _userLocation!.longitude),
        50000,
        type: 'tourist_attraction',
      );

      if (response.isOkay && response.results.isNotEmpty) {
        final places = response.results
            .where((result) => result.rating != null && result.rating! >= 4.0)
            .map((result) {
          return Place(
            id: result.placeId,
            name: result.name,
            description: result.vicinity ?? 'No description available',
            imageUrl: result.photos.isNotEmpty == true
                ? _getPhotoUrl(result.photos.first.photoReference)
                : 'assets/images/placeholder.jpg',
            latitude: result.geometry?.location.lat ?? 0.0,
            longitude: result.geometry?.location.lng ?? 0.0,
            category: result.types.isNotEmpty == true
                ? result.types.first
                : 'tourist_attraction',
            rating: result.rating?.toDouble() ?? 0.0,
            constructionHistory: 'Unknown',
            era: 'Unknown',
            builder: 'Unknown',
            audioUrl: '',
            indoorMap: [],
            routes: {},
            subCategory: _determineSubCategory(
              result.types.isNotEmpty == true ? result.types.first : 'unknown',
              result.name,
            ),
            imageUrls: [],
          );
        }).toList();
        return places;
      } else {
        return _getFallbackPlaces();
      }
    } catch (e) {
      _showMessageOverlay('Failed to load top-rated places: $e');
      return _getFallbackPlaces();
    }
  }

  List<Place> _getFallbackPlaces() {
    return [
      Place(
        id: 'fallback_pyramids',
        name: 'Pyramids of Giza',
        description: 'Iconic ancient pyramids in Giza',
        imageUrl:
        'https://images.pexels.com/photos/262786/pexels-photo-262786.jpeg?auto=compress&cs=tinysrgb&w=400',
        latitude: 29.9792,
        longitude: 31.1342,
        category: 'tourist_attraction',
        rating: 4.8,
        constructionHistory: 'Unknown',
        era: 'Unknown',
        builder: 'Unknown',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Historical/Cultural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_museum',
        name: 'Egyptian Museum',
        description: 'Museum of ancient Egyptian artifacts in Cairo',
        imageUrl:
        'https://images.pexels.com/photos/208701/pexels-photo-208701.jpeg?auto=compress&cs=tinysrgb&w=400',
        latitude: 30.0478,
        longitude: 31.2336,
        category: 'museum',
        rating: 4.6,
        constructionHistory: 'Unknown',
        era: 'Unknown',
        builder: 'Unknown',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Historical/Cultural',
        imageUrls: [],
      ),
    ];
  }

  void _navigateToNearbyPlaces() {
    if (_userLocation != null && mounted) {
      _topRatedFuture?.then((places) {
        if (places.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NearbyTouristSitesScreen(),
            ),
          );
        } else {
          _showMessageOverlay('No nearby places found');
        }
      }).catchError((e) {
        _showMessageOverlay('Error loading Nearby Places');
      });
    } else {
      _showMessageOverlay(
        AppLocalizations.of(context).translate('please_enable_location'),
      );
    }
  }

  Future<void> _initializeGovernorates() async {
    if (_governorates.isNotEmpty) return;

    final List<Map<String, dynamic>> tempGovernorates = [
      {
        'name': 'Cairo',
        'image': 'assets/images/gov/cairo.png',
        'places': [
          {'name': 'Pyramids of Giza', 'id': 'ChIJR8Y5NuVRWB4R2O4zZgViQ0Y'},
          {'name': 'Egyptian Museum', 'id': 'ChIJL1x8v-NRWB4R4Vq3z1z3z1I'},
        ],
      },
      {
        'name': 'Alexandria',
        'image': 'assets/images/gov/alexandria.png',
        'places': [
          {
            'name': 'Bibliotheca Alexandrina',
            'id': 'ChIJ6Wix0YFVWB4R3z1z3z1z3zI',
          },
          {'name': 'Citadel of Qaitbay', 'id': 'ChIJ2Wix0YFVWB4R3z1z3z1z3zI'},
        ],
      },
      {
        'name': 'Aswan',
        'image': 'assets/images/gov/aswan.png',
        'places': [
          {'name': 'Philae Temple', 'id': 'ChIJQ8Y5NuVRWB4R2O4zZgViQ0Y'},
          {'name': 'Abu Simbel', 'id': 'ChIJL1x8v-NRWB4R4Vq3z1z3z1I'},
        ],
      },
      {
        'name': 'South Sinai',
        'image': 'assets/images/gov/south_sinai.png',
        'places': [
          {
            'name': 'Saint Catherine’s Monastery',
            'id': 'ChIJQ8Y5NuVRWB4R2O4zZgViQ0Y',
          },
          {'name': 'Mount Sinai', 'id': 'ChIJL1x8v-NRWB4R4Vq3z1z3z1I'},
        ],
      },
      {
        'name': 'Red Sea',
        'image': 'assets/images/gov/red_sea.png',
        'places': [
          {'name': 'Hurghada Marina', 'id': 'ChIJQ8Y5NuVRWB4R2O4zZgViQ0Y'},
          {'name': 'Giftun Island', 'id': 'ChIJL1x8v-NRWB4R4Vq3z1z3z1I'},
        ],
      },
      {
        'name': 'Fayoum',
        'image': 'assets/images/gov/fayoum.png',
        'places': [
          {'name': 'Wadi El Rayan', 'id': 'ChIJQ8Y5NuVRWB4R2O4zZgViQ0Y'},
          {'name': 'Tunis Village', 'id': 'ChIJL1x8v-NRWB4R4Vq3z1z3z1I'},
        ],
      },
    ];

    if (mounted) {
      setState(() {
        _governorates = tempGovernorates.isNotEmpty
            ? tempGovernorates
            : [
          {
            'name': 'Fallback City',
            'image': 'assets/images/gov/fallback.png',
            'places': [
              {'name': 'Fallback Place', 'id': 'fallback_id'},
            ],
          },
        ];
      });
    }
  }

  void _scrollListener() {}

  Future<void> _loadSavedPlaces() async {
    try {
      if (_firestoreService == null) {
        return;
      }
      final favoritePlaces = await _firestoreService!.getFavoritePlaces().first;
      if (mounted) {
        setState(() {
          _savedPlaces = favoritePlaces.map((place) => place.id).toSet();
          _favoritePlaces = favoritePlaces;
        });
      }
    } catch (e) {
      _showMessageOverlay(
        '${AppLocalizations.of(context).translate('error_loading_places')}: $e',
      );
    }
  }

  Future<void> _toggleSavedPlace(String placeId) async {
    try {
      if (_firestoreService == null) {
        _showMessageOverlay(
            AppLocalizations.of(context).translate('please_sign_in'));
        return;
      }

      if (_savedPlaces.contains(placeId)) {
        await _firestoreService!.removeFavoritePlace(placeId);
        setState(() {
          _savedPlaces.remove(placeId);
          _favoritePlaces.removeWhere((place) => place.id == placeId);
        });
        _showMessageOverlay(
          AppLocalizations.of(context).translate('removed_from_favorites'),
          isError: false,
        );
      } else {
        final place = await _fetchPlaceById(placeId);
        if (place != null) {
          await _firestoreService!.saveFavoritePlace(place);
          setState(() {
            _savedPlaces.add(placeId);
            _favoritePlaces.add(place);
          });
          _showMessageOverlay(
            AppLocalizations.of(context).translate('added_to_favorites'),
            isError: false,
          );
        } else {
          _showMessageOverlay(
            AppLocalizations.of(context).translate('error_fetching_place'),
          );
        }
      }
      if (!_isLoadingRecommendations) {
        await _fetchRecommendations();
      }
    } catch (e) {
      _showMessageOverlay(
        '${AppLocalizations.of(context).translate('error_saving_place')}: $e',
      );
    }
  }

  Future<List<Place>> fetchPlacesForGovernorate(String governorate) async {
    if (_cachedPlaces.containsKey(governorate)) {
      return _cachedPlaces[governorate]!;
    }

    try {
      final governorateCoordinates = {
        'Cairo': Location(lat: 30.0444, lng: 31.2357),
        'Alexandria': Location(lat: 31.2001, lng: 29.9187),
        'Aswan': Location(lat: 24.0889, lng: 32.8998),
        'South Sinai': Location(lat: 27.7328, lng: 34.2455),
        'Red Sea': Location(lat: 25.0844, lng: 34.8915),
        'Fayoum': Location(lat: 29.3084, lng: 30.8441),
      };

      final center = governorateCoordinates[governorate] ??
          Location(lat: 26.8206, lng: 30.8025);
      final response = await placesApi.searchNearbyWithRadius(
        center,
        50000,
        type: 'tourist_attraction',
      );

      if (response.isOkay && response.results.isNotEmpty) {
        final places = response.results.map((result) {
          return Place(
            id: result.placeId,
            name: result.name,
            description: result.vicinity ?? 'No description available',
            imageUrl: result.photos.isNotEmpty == true
                ? _getPhotoUrl(result.photos.first.photoReference)
                : 'assets/images/placeholder.jpg',
            latitude: result.geometry?.location.lat ?? 0.0,
            longitude: result.geometry?.location.lng ?? 0.0,
            category: result.types.isNotEmpty == true
                ? result.types.first
                : 'tourist_attraction',
            rating: result.rating?.toDouble() ?? 0.0,
            constructionHistory: 'Unknown',
            era: 'Unknown',
            builder: 'Unknown',
            audioUrl: '',
            indoorMap: [],
            routes: {},
            subCategory: _determineSubCategory(
              result.types.isNotEmpty == true ? result.types.first : 'unknown',
              result.name,
            ),
            imageUrls: [],
          );
        }).toList();
        _cachedPlaces[governorate] = places;
        return places;
      } else {
        return _getFallbackPlaces();
      }
    } catch (e) {
      _showMessageOverlay('Failed to load places for $governorate: $e');
      return _getFallbackPlaces();
    }
  }

  String _getPhotoUrl(String photoReference) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=$googleApiKey';
  }

  String _determineSubCategory(String category, String name) {
    final nameLower = name.toLowerCase();
    if (category == 'tourist_attraction' ||
        nameLower.contains('tourist') ||
        nameLower.contains('temple') ||
        nameLower.contains('pyramid') ||
        nameLower.contains('museum')) {
      return 'Historical/Cultural';
    } else if (category == 'lodging' || nameLower.contains('hotel')) {
      return 'Hotels';
    } else if ((category == 'cafe' || category == 'restaurant') ||
        nameLower.contains('coffee')) {
      return 'Food & Drink';
    } else if (category == 'shopping_mall' || nameLower.contains('mall')) {
      return 'Malls';
    } else if (category == 'library') {
      return 'Educational';
    }
    return 'Other';
  }

  String _convertToApiCategory(String category) {
    switch (category) {
      case 'Historical/Cultural':
        return 'tourist_attraction';
      case 'Food & Drink':
        return 'restaurant';
      case 'Malls':
        return 'shopping_mall';
      case 'Hotels':
        return 'lodging';
      default:
        return 'tourist_attraction';
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentIndex < 4) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          _currentIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> _refreshPlaces() async {
    setState(() {
      _cachedPlaces.clear();
      _recommendedPlaces = [];
      _recommendationReasons = [];
      _hasAttemptedRecommendations = false;
      _isLoadingRecommendations = false;
      _topRatedFuture = _fetchTopRatedPlaces();
      if (_firestoreService != null) {
        Future.microtask(() => _initializeData());
      }
    });
  }

  void _navigateToPlaceDetails(Place place) async {
    try {
      if (_firestoreService != null) {
        await _firestoreService!.addRecentPlace(place);
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaceDetailsScreen(place: place),
        ),
      );
    } catch (e) {
      _showMessageOverlay('Error saving recent place: $e');
    }
  }

  Widget _buildRatingWidget(double rating) {
    return Row(
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          size: 16,
          color: Colors.amber,
        );
      }),
    );
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessageOverlay(
            AppLocalizations.of(context).translate('location_permission_denied'),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showMessageOverlay(
          AppLocalizations.of(context)
              .translate('location_permission_permanently_denied'),
        );
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _userLocation = position;
          _topRatedFuture = _fetchTopRatedPlaces();
        });
      }
    } catch (e) {
      _showMessageOverlay(
        '${AppLocalizations.of(context).translate('error_getting_location')}: $e',
      );
    }
  }

  Future<void> _fetchRecommendations() async {
    if (_isLoadingRecommendations || _firestoreService == null) {
      return;
    }

    if (_favoritePlaces.isEmpty) {
      setState(() {
        _recommendedPlaces = [];
        _recommendationReasons = [];
        _isLoadingRecommendations = false;
        _hasAttemptedRecommendations = true;
      });
      _showMessageOverlay(
        AppLocalizations.of(context)
            .translate('add_favorites_to_get_recommendations'),
      );
      return;
    }

    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final categoryCounts = <String, int>{};
      double latSum = 0.0, lngSum = 0.0;
      for (var place in _favoritePlaces) {
        final category = place.subCategory ?? 'Other';
        categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
        latSum += place.latitude;
        lngSum += place.longitude;
      }

      final centerLat = latSum / _favoritePlaces.length;
      final centerLng = lngSum / _favoritePlaces.length;

      final sortedCategories = categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final categoriesToSearch = sortedCategories
          .map((e) => e.key)
          .take(2)
          .toList();
      if (categoriesToSearch.isEmpty) {
        categoriesToSearch.add('Historical/Cultural');
      }

      final allPlacesMap = <String, Place>{};
      for (var category in categoriesToSearch) {
        final apiCategory = _convertToApiCategory(category);
        final response = await placesApi
            .searchNearbyWithRadius(
          Location(lat: centerLat, lng: centerLng),
          100000,
          type: apiCategory,
          keyword: 'Egypt',
        )
            .timeout(Duration(seconds: 15));

        if (response.isOkay) {
          for (var result in response.results) {
            final lat = result.geometry?.location.lat;
            final lng = result.geometry?.location.lng;
            if (lat != null && lng != null) {
              final place = Place(
                id: result.placeId,
                name: result.name,
                description: result.vicinity ?? 'No description available',
                imageUrl: result.photos.isNotEmpty == true
                    ? _getPhotoUrl(result.photos.first.photoReference)
                    : 'https://via.placeholder.com/400',
                latitude: lat,
                longitude: lng,
                category: result.types.isNotEmpty == true
                    ? result.types.first
                    : 'tourist_attraction',
                rating: result.rating?.toDouble() ?? 4.0,
                constructionHistory: 'Unknown',
                era: 'Unknown',
                builder: 'Unknown',
                audioUrl: '',
                indoorMap: [],
                routes: {},
                subCategory: _determineSubCategory(
                  result.types.first,
                  result.name,
                ),
                imageUrls: [],
              );
              allPlacesMap[place.id] = place;
            }
          }
        } else {}
      }

      final allPlaces = allPlacesMap.values.toList();
      final scoredPlaces = allPlaces.map((place) {
        double score = 0.0;
        final category = place.subCategory ?? 'Other';
        final categoryWeight = categoriesToSearch.contains(category) ? 0.6 : 0.2;
        score += categoryWeight * 0.5;
        score += (place.rating / 5.0) * 0.3;
        final distance = _calculateDistance(
          centerLat,
          centerLng,
          place.latitude,
          place.longitude,
        );
        score += (1.0 - min(distance / 100.0, 1.0)) * 0.2;
        return {'place': place, 'score': score};
      }).toList();

      scoredPlaces.sort(
            (a, b) => (b['score'] as num).compareTo(a['score'] as num),
      );
      final uniqueRecommended = <String, Place>{};
      for (var item in scoredPlaces) {
        final place = item['place'] as Place;
        if (!_savedPlaces.contains(place.id)) {
          uniqueRecommended[place.id] = place;
          if (uniqueRecommended.length >= 6) break;
        }
      }

      final recommended = uniqueRecommended.values.toList();
      final reasons = recommended.map((place) {
        final category = place.subCategory ?? 'Other';
        return 'Based on your interest in $category places';
      }).toList();

      setState(() {
        _recommendedPlaces = recommended;
        _recommendationReasons = reasons;
        _isLoadingRecommendations = false;
        _hasAttemptedRecommendations = true;
      });
    } catch (e) {
      _showMessageOverlay('Error fetching recommendations: $e');
      setState(() {
        _recommendedPlaces = [];
        _recommendationReasons = [];
        _isLoadingRecommendations = false;
        _hasAttemptedRecommendations = true;
      });
    }
  }

  double _calculateDistance(
      double lat1,
      double lng1,
      double lat2,
      double lng2,
      ) {
    const R = 6371e3;
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final deltaPhi = (lat2 - lat1) * pi / 180;
    final deltaLambda = (lng2 - lng1) * pi / 180;

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c / 1000;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Provider.of<AppState>(context, listen: false);
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'GuideMe',
          style: Theme.of(context)
              .textTheme
              .headlineLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SearchScreen(
                    places: [],
                    scrollController: _fallbackScrollController,
                  ),
                ),
              );
            },
            tooltip: localizations.translate('search'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshPlaces,
        child: CustomScrollView(
          controller: _fallbackScrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 10.0),
              sliver: SliverToBoxAdapter(
                child: Text(
                  localizations.translate('going_to'),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              sliver: _governorates.isEmpty
                  ? const SliverToBoxAdapter(
                child: Center(child: CircularProgressIndicator()),
              )
                  : SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: PageView.builder(
                    itemCount: _governorates.length,
                    padEnds: false,
                    pageSnapping: true,
                    controller: PageController(
                      viewportFraction: 0.45,
                      initialPage: 0,
                    ),
                    itemBuilder: (context, index) {
                      final governorate = _governorates[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: AnimatedOpacity(
                          opacity: 1.0,
                          duration:
                          Duration(milliseconds: 500 + (index * 100)),
                          curve: Curves.easeInOut,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      GovernoratePlacesScreen(
                                        governorate: governorate['name'],
                                        fetchPlaces: fetchPlacesForGovernorate,
                                        toggleSavedPlace: _toggleSavedPlace,
                                        savedPlaces: _savedPlaces,
                                      ),
                                ),
                              );
                            },
                            child: SizedBox(
                              width: 160,
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                elevation: 4,
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(15),
                                      child: Image.asset(
                                        governorate['image'],
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                            ) {
                                          debugPrint(
                                            'Image load error for ${governorate['name']} (Path: ${governorate['image']}): $error\nStackTrace: $stackTrace',
                                          );
                                          return Container(
                                            color: Colors.grey[300],
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                MainAxisAlignment
                                                    .center,
                                                children: [
                                                  const Icon(
                                                    Icons.error,
                                                    size: 50,
                                                    color: Colors.red,
                                                  ),
                                                  Text(
                                                    governorate['name'],
                                                    style: const TextStyle(
                                                      color: Colors.black,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10,
                                      left: 10,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withOpacity(0.5),
                                          borderRadius:
                                          BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          governorate['name'],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFD4B087).withOpacity(0.8),
                        Colors.black.withOpacity(0.6),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _navigateToNearbyPlaces,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      localizations.translate('discover_nearby_locations'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_userLocation != null) ...[
              if (_firestoreService != null)
                LastSeenSection(
                  firestoreService: _firestoreService!,
                  navigateToPlaceDetails: _navigateToPlaceDetails,
                  toggleSavedPlace: _toggleSavedPlace,
                  savedPlaces: _savedPlaces,
                ),
              RecommendationsSection(
                recommendedPlaces: _recommendedPlaces,
                recommendationReasons: _recommendationReasons,
                isLoadingRecommendations: _isLoadingRecommendations,
                hasAttemptedRecommendations: _hasAttemptedRecommendations,
                favoritePlaces: _favoritePlaces,
                onRefresh: _fetchRecommendations,
                onNavigateToPlaceDetails: _navigateToPlaceDetails,
                onToggleSavedPlace: _toggleSavedPlace,
              ),
              MustVisitSpots(
                key: _mustVisitSpotsKey,
                places: placesApi,
                toggleSavedPlace: _toggleSavedPlace,
                savedPlaces: _savedPlaces,
                navigateToPlaceDetails: _navigateToPlaceDetails,
                userLocation: _userLocation,
              ),
              HiddenGems(
                key: _hiddenGemsKey,
                placesApi: placesApi,
                toggleSavedPlace: _toggleSavedPlace,
                savedPlaces: _savedPlaces,
                navigateToPlaceDetails: _navigateToPlaceDetails,
                buildRatingStars: _buildRatingWidget,
                userLocation: _userLocation,
              ),
            ] else
              SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      AppLocalizations.of(context)
                          .translate('waiting_for_location'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}