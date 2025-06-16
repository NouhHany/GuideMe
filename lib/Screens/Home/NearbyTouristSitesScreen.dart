import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guideme/Models/Place.dart';
import 'package:guideme/Services/firestore_service.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/AppLocalizations.dart';
import '../Place Details/placedetails.dart';

class NearbyTouristSitesScreen extends StatefulWidget {
  const NearbyTouristSitesScreen({super.key});

  @override
  _NearbyTouristSitesScreenState createState() =>
      _NearbyTouristSitesScreenState();
}

class _NearbyTouristSitesScreenState extends State<NearbyTouristSitesScreen> {
  List<Place> _places = [];
  List<Place> _filteredPlaces = [];
  bool _isLoading = true;
  bool _isLocationLoading = true;
  String _errorMessage = '';
  Position? _currentPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  GoogleMapController? _mapController;
  final double _currentZoom = 13.0;
  final Set<String> _favorites = {};
  final List<bool> _filterSelections = [
    true,
    true,
    true,
    true,
  ]; // Hotels, Coffee Shops, Malls, Tourist Sites
  final GoogleMapsPlaces _placesApi = GoogleMapsPlaces(
    apiKey: 'AIzaSyD3iQPOazh9GfAOl44Y9kDHDJ0zyNqARSA',
  );
  final String _fallbackImageUrl = 'https://via.placeholder.com/400';

  @override
  void initState() {
    super.initState();
    debugPrint('NearbyTouristSitesScreen: initState called');
    _loadFavorites();
    _fetchPlacesAndStartLocationUpdates();
  }

  Future<void> _loadFavorites() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      final firestoreService = FirestoreService(userId: user.uid);
      final favoritePlaces = await firestoreService.getFavoritePlaces().first;
      setState(() {
        _favorites.clear();
        _favorites.addAll(favoritePlaces.map((place) => place.id));
      });
      debugPrint(
        'NearbyTouristSitesScreen: Loaded ${_favorites.length} favorites',
      );
    }
  }

  Future<void> _toggleFavorite(Place place) async {
    if (mounted) {
      debugPrint('Toggling favorite for ${place.name}');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('please_sign_in'),
            ),
          ),
        );
        return;
      }
      final firestoreService = FirestoreService(userId: user.uid);
      try {
        setState(() {
          if (_favorites.contains(place.id)) {
            _favorites.remove(place.id);
            firestoreService.removeFavoritePlace(place.id);
          } else {
            _favorites.add(place.id);
            firestoreService.saveFavoritePlace(place);
          }
        });
      } catch (e) {
        debugPrint('Error in _toggleFavorite: $e');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error toggling favorite: $e')));
      }
    }
  }

  Future<void> _fetchPlacesAndStartLocationUpdates() async {
    setState(() {
      _isLoading = true;
      _isLocationLoading = true;
    });
    try {
      await _startLocationUpdates();
      if (_currentPosition != null && mounted) {
        await _fetchNearbyPlaces();
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLocationLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchPlacesAndStartLocationUpdates: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLocationLoading = false;
          _errorMessage = AppLocalizations.of(
            context,
          ).translate('error_loading_places');
        });
      }
    }
  }

  Future<void> _startLocationUpdates() async {
    try {
      debugPrint('Checking location permission');
      bool permissionGranted = await _requestLocationPermission();
      if (!permissionGranted) {
        if (mounted) {
          setState(() {
            _isLocationLoading = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                ).translate('please_enable_location'),
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () async {
                  debugPrint('Opening app settings');
                  await openAppSettings();
                  if (mounted) {
                    _fetchPlacesAndStartLocationUpdates();
                  }
                },
              ),
            ),
          );
        }
        return;
      }

      debugPrint('Checking location services');
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocationLoading = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                ).translate('please_enable_location'),
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () async {
                  debugPrint('Opening location settings');
                  await Geolocator.openLocationSettings();
                  if (mounted) {
                    _fetchPlacesAndStartLocationUpdates();
                  }
                },
              ),
            ),
          );
        }
        return;
      }

      debugPrint('Starting position stream');
      _positionStreamSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(
        (Position position) {
          if (mounted) {
            debugPrint('Position received: $position');
            setState(() {
              _currentPosition = position;
              _isLocationLoading = false;
            });
            if (_currentPosition != null && _mapController != null) {
              debugPrint(
                'Updating map camera to ${position.latitude}, ${position.longitude}',
              );
              _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: _currentZoom,
                  ),
                ),
              );
              _fetchNearbyPlaces();
            }
          }
        },
        onError: (e) {
          debugPrint('Position stream error: $e');
          if (mounted) {
            setState(() {
              _isLocationLoading = true;
            });
          }
        },
      );
    } catch (e) {
      debugPrint('Error in _startLocationUpdates: $e');
      if (mounted) {
        setState(() {
          _isLocationLoading = true;
        });
      }
    }
  }

  Future<void> _fetchNearbyPlaces() async {
    if (_currentPosition == null || !mounted) {
      debugPrint('No current position or not mounted');
      return;
    }

    final center = Location(
      lat: _currentPosition!.latitude,
      lng: _currentPosition!.longitude,
    );
    final radiusTiers = [10000, 20000, 50000];
    final keywords = ['hotel', 'cafe', 'shopping_mall', 'tourist_attraction'];
    List<Place> places = [];

    try {
      debugPrint('Fetching places for location: ${center.lat}, ${center.lng}');
      for (var radius in radiusTiers) {
        for (var keyword in keywords) {
          debugPrint('Searching with keyword: $keyword, radius: $radius');
          final response = await _placesApi.searchNearbyWithRadius(
            center,
            radius,
            type: keyword,
          );
          if (response.isOkay && response.results.isNotEmpty) {
            places.addAll(
              response.results.map((result) {
                String category = result.types.first;
                String subCategory = _determineSubCategory(
                  category,
                  result.name,
                );
                String? photoReference =
                    result.photos.isNotEmpty == true
                        ? result.photos.first.photoReference
                        : null;
                String imageUrl =
                    photoReference != null
                        ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=AIzaSyD3iQPOazh9GfAOl44Y9kDHDJ0zyNqARSA'
                        : _fallbackImageUrl;
                debugPrint(
                  'Adding place: ${result.name}, Category: $subCategory, Rating: ${result.rating}',
                );
                return Place(
                  id: result.placeId,
                  name: result.name,
                  description: result.vicinity ?? 'No description available',
                  imageUrl: imageUrl,
                  latitude: result.geometry?.location.lat ?? 0.0,
                  longitude: result.geometry?.location.lng ?? 0.0,
                  category: category,
                  rating: result.rating?.toDouble() ?? 0.0,
                  constructionHistory: 'Unknown',
                  era: 'Unknown',
                  builder: 'Unknown',
                  audioUrl: '',
                  indoorMap: [],
                  routes: {},
                  subCategory: subCategory,
                  imageUrls: [],
                );
              }).toList(),
            );
          } else {
            debugPrint(
              'API response empty or not okay for keyword $keyword: ${response.errorMessage}',
            );
          }
        }
        if (places.isNotEmpty) break;
      }

      if (mounted) {
        debugPrint('Fetched ${places.length} places');
        places.sort((a, b) {
          double distA = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            a.latitude,
            a.longitude,
          );
          double distB = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            b.latitude,
            b.longitude,
          );
          return distA.compareTo(distB);
        });
        setState(() {
          _places = places;
          _applyFilters();
        });
      }
    } catch (e) {
      debugPrint('Error in _fetchNearbyPlaces: $e');
      if (mounted) {
        setState(() {
          _errorMessage = AppLocalizations.of(
            context,
          ).translate('error_loading_places');
        });
      }
    }
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
    } else if (category == 'cafe' ||
        category == 'restaurant' ||
        nameLower.contains('coffee')) {
      return 'Food & Drink';
    } else if (category == 'shopping_mall' || nameLower.contains('mall')) {
      return 'Malls';
    }
    return 'Other';
  }

  void _applyFilters() {
    if (!mounted) return;

    List<Place> filteredPlaces =
        _places.where((place) {
          if (!_filterSelections.contains(true)) return true;
          bool matches = false;
          if (_filterSelections[0] && place.subCategory == 'Hotels') {
            matches = true;
          }
          if (_filterSelections[1] && place.subCategory == 'Food & Drink') {
            matches = true;
          }
          if (_filterSelections[2] && place.subCategory == 'Malls') {
            matches = true;
          }
          if (_filterSelections[3] &&
              place.subCategory == 'Historical/Cultural') {
            matches = true;
          }
          return matches;
        }).toList();

    filteredPlaces.sort((a, b) {
      double distA = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        a.latitude,
        a.longitude,
      );
      double distB = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        b.latitude,
        b.longitude,
      );
      return distA.compareTo(distB);
    });

    debugPrint('Applied filters, ${filteredPlaces.length} places remain');
    setState(() {
      _filteredPlaces = filteredPlaces;
    });
  }

  Future<bool> _requestLocationPermission() async {
    try {
      final status = await Permission.location.request();
      debugPrint('Permission status: $status');
      if (status.isPermanentlyDenied) {
        if (mounted) {
          setState(() {
            _isLocationLoading = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(
                  context,
                ).translate('please_enable_location'),
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () async {
                  debugPrint('Opening app settings');
                  await openAppSettings();
                  if (mounted) {
                    _fetchPlacesAndStartLocationUpdates();
                  }
                },
              ),
            ),
          );
        }
        return false;
      }
      return status.isGranted;
    } catch (e) {
      debugPrint('Error in _requestLocationPermission: $e');
      return false;
    }
  }

  void _navigateToPlaceDetails(Place place) {
    try {
      debugPrint('Navigating to PlaceDetailsScreen for ${place.name}');
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final firestoreService = FirestoreService(userId: user.uid);
        firestoreService.addRecentPlace(place).catchError((e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving recent place: $e')),
          );
        });
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlaceDetailsScreen(place: place),
        ),
      );
    } catch (e) {
      debugPrint('Error in _navigateToPlaceDetails: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).translate('error_loading_places'),
            ),
          ),
        );
      }
    }
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            return Icon(
              index < rating.floor() ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 16,
            );
          }),
        ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  String _formatDistance(double latitude, double longitude) {
    if (_currentPosition == null) return 'Distance unavailable';
    try {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        latitude,
        longitude,
      );
      return distance < 1000
          ? '${distance.toStringAsFixed(0)} m'
          : '${(distance / 1000).toStringAsFixed(1)} km';
    } catch (e) {
      debugPrint('Error in _formatDistance: $e');
      return 'Distance unavailable';
    }
  }

  @override
  void dispose() {
    debugPrint('NearbyTouristSitesScreen: dispose called');
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backArrowColor = isDarkMode ? Colors.white : Colors.black;
    final localizations = AppLocalizations.of(context);

    try {
      AppLocalizations.of(context).translate('please_enable_location');
    } catch (e) {
      debugPrint('AppLocalizations error: $e');
      if (mounted) {
        setState(() => _errorMessage = 'Translation error');
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('Nearby locations'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: backArrowColor),
          onPressed: () {
            debugPrint('Back button pressed');
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child:
            _isLoading || _isLocationLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_errorMessage),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchPlacesAndStartLocationUpdates,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4B087),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          AppLocalizations.of(context).translate('retry'),
                        ),
                      ),
                    ],
                  ),
                )
                : Column(
                  children: [
                    Container(
                      height: 250,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            _currentPosition == null
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : GoogleMap(
                                  onMapCreated: (
                                    GoogleMapController controller,
                                  ) {
                                    debugPrint('Map created');
                                    _mapController = controller;
                                    _fetchNearbyPlaces();
                                  },
                                  initialCameraPosition: CameraPosition(
                                    target: LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    ),
                                    zoom: _currentZoom,
                                  ),
                                  minMaxZoomPreference:
                                      const MinMaxZoomPreference(10.0, 18.0),
                                  markers: {
                                    Marker(
                                      markerId: const MarkerId(
                                        'current_location',
                                      ),
                                      position: LatLng(
                                        _currentPosition!.latitude,
                                        _currentPosition!.longitude,
                                      ),
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueBlue,
                                          ),
                                      infoWindow: const InfoWindow(
                                        title: 'You are here',
                                      ),
                                    ),
                                    ..._filteredPlaces.map((place) {
                                      return Marker(
                                        markerId: MarkerId(place.id),
                                        position: LatLng(
                                          place.latitude,
                                          place.longitude,
                                        ),
                                        icon:
                                            BitmapDescriptor.defaultMarkerWithHue(
                                              place.subCategory == 'Hotels'
                                                  ? BitmapDescriptor.hueRed
                                                  : place.subCategory ==
                                                      'Food & Drink'
                                                  ? BitmapDescriptor.hueGreen
                                                  : place.subCategory == 'Malls'
                                                  ? BitmapDescriptor.hueYellow
                                                  : BitmapDescriptor.hueOrange,
                                            ),
                                        infoWindow: InfoWindow(
                                          title: place.name,
                                          snippet:
                                              '${place.subCategory} (Rating: ${place.rating})',
                                        ),
                                        onTap:
                                            () => _navigateToPlaceDetails(
                                              place,
                                            ), // Track map marker taps
                                      );
                                    }).toSet(),
                                  },
                                ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const SizedBox(width: 8),
                            _buildFilterButton('Hotels', 0),
                            const SizedBox(width: 8),
                            _buildFilterButton('Coffee Shops', 1),
                            const SizedBox(width: 8),
                            _buildFilterButton('Malls', 2),
                            const SizedBox(width: 8),
                            _buildFilterButton('Tourist Sites', 3),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          _filteredPlaces.isEmpty
                              ? const Center(child: CircularProgressIndicator())
                              : Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                ),
                                child: GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 0.7,
                                      ),
                                  itemCount: _filteredPlaces.length,
                                  itemBuilder: (context, index) {
                                    final place = _filteredPlaces[index];
                                    bool isFavorite = _favorites.contains(
                                      place.id,
                                    );
                                    return GestureDetector(
                                      onTap:
                                          () => _navigateToPlaceDetails(place),
                                      child: Card(
                                        elevation: 4,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(12),
                                                    ),
                                                child: Image.network(
                                                  place.imageUrl,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) {
                                                    debugPrint(
                                                      'Image load error for ${place.name} (URL: ${place.imageUrl}): $error',
                                                    );
                                                    return const Icon(
                                                      Icons.error,
                                                      size: 50,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          place.name,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 16,
                                                              ),
                                                          maxLines: 1,
                                                          overflow:
                                                              TextOverflow
                                                                  .ellipsis,
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(
                                                          isFavorite
                                                              ? Icons.favorite
                                                              : Icons
                                                                  .favorite_border,
                                                          color:
                                                              isFavorite
                                                                  ? Colors.red
                                                                  : null,
                                                        ),
                                                        onPressed:
                                                            () =>
                                                                _toggleFavorite(
                                                                  place,
                                                                ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  _buildRatingStars(
                                                    place.rating,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatDistance(
                                                      place.latitude,
                                                      place.longitude,
                                                    ),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey[600],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _buildFilterButton(String label, int index) {
    return ElevatedButton(
      onPressed: () {
        if (mounted) {
          debugPrint('Filter button pressed: $label');
          setState(() {
            _filterSelections[index] = !_filterSelections[index];
            _applyFilters();
          });
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _filterSelections[index]
                ? const Color(0xFFD4B087)
                : Colors.grey[300],
        foregroundColor: _filterSelections[index] ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label),
    );
  }
}
