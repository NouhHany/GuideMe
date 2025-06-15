import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import '../../Models/Place.dart';
import '../../Services/firestore_service.dart';
import '../../core/AppLocalizations.dart';
import '../Home/Home Screen/recommendations_section.dart';
import '../Place Details/placedetails.dart';
import 'TripCreationScreen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Place> _favoritePlaces = [];
  Set<String> _savedPlaceIds = {};
  bool _listView = false;
  final ScrollController _controller = ScrollController();
  final ScrollController _gridController = ScrollController();
  final GoogleMapsPlaces placesApi = GoogleMapsPlaces(
    apiKey: 'AIzaSyD3iQPOazh9GfAOl44Y9kDHDJ0zyNqARSA',
  );
  List<Map<String, dynamic>> _userTrips = [];
  late FirestoreService _firestoreService;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestoreService = FirestoreService(userId: user.uid);
      _loadFavoritePlaces();
    } else {
      _showSnackBar('Please sign in to view favorites.');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _gridController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoritePlaces() async {
    try {
      final places = await _firestoreService.getFavoritePlaces().first;
      print('Loaded favorite places: ${places.map((p) => p.name).toList()}');
      setState(() {
        _favoritePlaces = places;
        _savedPlaceIds = places.map((place) => place.id).toSet();
      });
    } catch (e) {
      print('Error loading favorite places: $e');
      _showSnackBar('Error loading favorite places.');
    }
  }

  Future<Place?> _fetchPlaceById(String placeId) async {
    try {
      final response = await placesApi.getDetailsByPlaceId(placeId).timeout(Duration(seconds: 10));
      if (response.isOkay) {
        final result = response.result;
        if (result.name == null || result.geometry?.location == null) {
          print('Invalid place data for placeId: $placeId');
          return null;
        }
        return Place(
          id: result.placeId ?? '',
          name: result.name!,
          description: result.vicinity ?? 'No description available',
          imageUrl: result.photos?.isNotEmpty == true
              ? _getPhotoUrl(result.photos!.first.photoReference!)
              : 'https://via.placeholder.com/400',
          latitude: result.geometry!.location.lat,
          longitude: result.geometry!.location.lng,
          category: result.types?.isNotEmpty == true ? result.types!.first : 'tourist_attraction',
          rating: result.rating?.toDouble() ?? 4.0,
          constructionHistory: 'Unknown',
          era: 'Unknown',
          builder: 'Unknown',
          audioUrl: '',
          indoorMap: [],
          routes: {},
          subCategory: _determineSubCategory(
            result.types?.isNotEmpty == true ? result.types!.first : 'unknown',
            result.name!,
          ),
          imageUrls: [],
        );
      }
      print('Place API response not okay for placeId: $placeId, status: ${response.status}');
      return null;
    } catch (e) {
      print('Error fetching place $placeId: $e');
      _showSnackBar('Error fetching place details.');
      return null;
    }
  }

  String _getPhotoUrl(String photoReference) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=AIzaSyD3iQPOazh9GfAOl44Y9kDHDJ0zyNqARSA';
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
    } else if (category == 'cafe' || category == 'restaurant' || nameLower.contains('coffee')) {
      return 'Food & Drink';
    } else if (category == 'shopping_mall' || nameLower.contains('mall')) {
      return 'Malls';
    }
    return 'Other';
  }

  Future<void> _toggleSavedPlace(String placeId) async {
    try {
      final place = await _fetchPlaceById(placeId);
      if (place == null) {
        _showSnackBar('Could not find place details.');
        return;
      }
      if (_savedPlaceIds.contains(placeId)) {
        await _firestoreService.removeFavoritePlace(placeId);
        _showSnackBar('Removed from favorites.');
      } else {
        await _firestoreService.saveFavoritePlace(place);
        _showSnackBar('Added to favorites.');
      }
      await _loadFavoritePlaces(); // Reload to update state
    } catch (e) {
      print('Error toggling favorite: $e');
      _showSnackBar('Error toggling favorite.');
    }
  }

  void _createManualTrip() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TripCreationScreen(
          favoritePlaces: _favoritePlaces,
          onTripCreated: (String tripName, List<Place> trip) {
            _firestoreService.saveTrip(tripName, trip);
          },
        ),
      ),
    );
  }

  void _navigateToPlaceDetails(Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlaceDetailsScreen(place: place)),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildRatingWidget(double rating) {
    return Text(
      rating.toStringAsFixed(1),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildPlaceCard(Place place, {bool showFavoriteButton = true}) {
    final isSaved = _savedPlaceIds.contains(place.id);
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _navigateToPlaceDetails(place),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    place.imageUrl,
                    width: double.infinity,
                    height: 112,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 112,
                        color: theme.colorScheme.surfaceContainer,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 112,
                        color: theme.colorScheme.surfaceContainer,
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _buildRatingWidget(place.rating),
                    ],
                  ),
                ),
              ],
            ),
            if (showFavoriteButton)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    isSaved ? Icons.favorite : Icons.favorite_border,
                    color: isSaved ? Colors.red : theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  onPressed: () => _toggleSavedPlace(place.id),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
                    shape: const CircleBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.translate('Favorites'))),
        body: const Center(child: Text('Please sign in to view favorites.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('Favorites'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_listView ? Icons.grid_view : Icons.list),
            onPressed: () {
              setState(() {
                _listView = !_listView;
              });
            },
            tooltip: localizations.translate('toggle_view'),
          ),
        ],
      ),
      body: StreamBuilder<List<Place>>(
        stream: _firestoreService.getFavoritePlaces(),
        builder: (context, favoritePlacesSnapshot) {
          if (favoritePlacesSnapshot.connectionState == ConnectionState.waiting) {
            print('Waiting for favorite places');
            return const Center(child: CircularProgressIndicator());
          }
          if (favoritePlacesSnapshot.hasError) {
            print('Favorite places error: ${favoritePlacesSnapshot.error}');
            return Center(child: Text('Error: ${favoritePlacesSnapshot.error}'));
          }
          _favoritePlaces = favoritePlacesSnapshot.data ?? [];
          _savedPlaceIds = _favoritePlaces.map((place) => place.id).toSet();

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _firestoreService.getTrips(),
            builder: (context, tripsSnapshot) {
              if (tripsSnapshot.connectionState == ConnectionState.waiting) {
                print('Waiting for trips');
                return const Center(child: CircularProgressIndicator());
              }
              if (tripsSnapshot.hasError) {
                print('Trips error: ${tripsSnapshot.error}');
                return Center(child: Text('Error: ${tripsSnapshot.error}'));
              }
              _userTrips = tripsSnapshot.data ?? [];
              print('Trips count: ${_userTrips.length}');

              if (_favoritePlaces.isEmpty && _userTrips.isEmpty) {
                return Center(
                  child: Text(
                    localizations.translate('no_favorite_places_yet'),
                    style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).unselectedWidgetColor,
                    ),
                  ),
                );
              }

              return Scrollbar(
                thumbVisibility: false,
                controller: _controller,
                child: CustomScrollView(
                  controller: _controller,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(12),
                      sliver: SliverToBoxAdapter(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.45,
                          ),
                          child: SingleChildScrollView(
                            controller: _gridController,
                            physics: const ClampingScrollPhysics(),
                            child: _listView
                                ? Column(
                              children: List.generate(
                                _favoritePlaces.length,
                                    (index) {
                                  final place = _favoritePlaces[index];
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                                      leading: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          place.imageUrl,
                                          width: 50,
                                          height: 50,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.error),
                                        ),
                                      ),
                                      title: Text(
                                        place.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: _buildRatingWidget(place.rating),
                                      trailing: IconButton(
                                        icon: Icon(
                                          _savedPlaceIds.contains(place.id)
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: _savedPlaceIds.contains(place.id)
                                              ? Colors.red
                                              : Colors.grey,
                                        ),
                                        onPressed: () => _toggleSavedPlace(place.id),
                                      ),
                                      onTap: () => _navigateToPlaceDetails(place),
                                    ),
                                  );
                                },
                              ),
                            )
                                : GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: EdgeInsets.zero,
                              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 160,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 160 / 260,
                              ),
                              itemCount: _favoritePlaces.length,
                              itemBuilder: (context, index) {
                                return _buildPlaceCard(_favoritePlaces[index]);
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 10.0),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              localizations.translate('your_trips'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            TextButton(
                              onPressed: _createManualTrip,
                              child: Text(
                                localizations.translate('create_trip'),
                                style: const TextStyle(color: Color(0xFFD4B087)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final trip = _userTrips[index];
                          final tripName = trip['name'] as String;
                          final places = trip['places'] as List<Place>;
                          return ExpansionTile(
                            title: Text(
                              tripName,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            children: [
                              SizedBox(
                                height: 260,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  itemCount: places.length,
                                  itemBuilder: (context, idx) {
                                    return Container(
                                      width: 160,
                                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                                      child: _buildPlaceCard(places[idx], showFavoriteButton: false),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                        childCount: _userTrips.length,
                      ),
                    ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 40.0)),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}