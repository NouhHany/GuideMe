import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guideme/Models/Place.dart';
import '../../../core/AppLocalizations.dart';

class MustVisitSpots extends StatefulWidget {
  final GoogleMapsPlaces places;
  final Function(String) toggleSavedPlace;
  final Set<String> savedPlaces;
  final Function(Place) navigateToPlaceDetails;
  final Widget Function(double) buildRatingStars;
  final Position? userLocation;

  const MustVisitSpots({
    super.key,
    required this.places,
    required this.toggleSavedPlace,
    required this.savedPlaces,
    required this.navigateToPlaceDetails,
    required this.buildRatingStars,
    this.userLocation,
  });

  @override
  _MustVisitSpotsState createState() => _MustVisitSpotsState();
}

class _MustVisitSpotsState extends State<MustVisitSpots> {
  late Future<List<Place>> _mustVisitFuture;

  @override
  void initState() {
    super.initState();
    _mustVisitFuture = fetchMustVisitPlaces();
  }

  Future<List<Place>> fetchMustVisitPlaces() async {
    try {
      if (widget.userLocation == null) {
        return _getFallbackPlaces();
      }

      final mustVisitPlaces = [
        {
          'name': 'Pyramids of Giza',
          'lat': 29.9792,
          'lng': 31.1342,
          'category': 'tourist_attraction',
        },
        {
          'name': 'Egyptian Museum',
          'lat': 30.0478,
          'lng': 31.2336,
          'category': 'museum',
        },
        {
          'name': 'Khan el-Khalili',
          'lat': 30.0475,
          'lng': 31.2622,
          'category': 'tourist_attraction',
        },
        {
          'name': 'Philae Temple',
          'lat': 24.0259,
          'lng': 32.8845,
          'category': 'tourist_attraction',
        },
        {
          'name': 'Bibliotheca Alexandrina',
          'lat': 31.2089,
          'lng': 29.9092,
          'category': 'library',
        },
      ];

      List<Place> places = [];
      final acceptableCategories = {
        'tourist_attraction',
        'museum',
        'shopping_mall',
        'library',
        'mosque',
        'church',
      };

      for (var place in mustVisitPlaces) {
        final center = Location(
          lat: (place['lat'] as num).toDouble(),
          lng: (place['lng'] as num).toDouble(),
        );
        final response = await widget.places.searchNearbyWithRadius(
          center,
          1000,
          type: place['category'] as String,
        );

        if (response.isOkay && response.results.isNotEmpty) {
          final result = response.results.firstWhere(
                (r) => r.name.toLowerCase().contains((place['name'] as String).toLowerCase()),
            orElse: () => response.results.first,
          );
          if (result.rating != null &&
              result.rating! >= 4.0 &&
              acceptableCategories.contains(result.types?.first)) {
            places.add(
              Place(
                id: result.placeId ?? '',
                name: result.name ?? place['name'] as String,
                description: result.vicinity ?? 'No description available',
                imageUrl: result.photos?.isNotEmpty == true
                    ? _getPhotoUrl(result.photos!.first.photoReference!)
                    : 'assets/images/placeholder.jpg',
                latitude: result.geometry?.location.lat ?? (place['lat'] as num).toDouble(),
                longitude: result.geometry?.location.lng ?? (place['lng'] as num).toDouble(),
                category: place['category'] as String,
                rating: result.rating?.toDouble() ?? 0.0,
                constructionHistory: 'Unknown',
                era: 'Unknown',
                builder: 'Unknown',
                audioUrl: '',
                indoorMap: [],
                routes: {},
                subCategory: _determineSubCategory(
                  result.types?.isNotEmpty == true ? result.types!.first : place['category'] as String,
                  result.name ?? place['name'] as String,
                ),
                imageUrls: [],
              ),
            );
          }
        }
      }

      return places.isNotEmpty ? places : _getFallbackPlaces();
    } catch (e) {
      debugPrint('Error fetching must-visit places: $e');
      return _getFallbackPlaces();
    }
  }

  List<Place> _getFallbackPlaces() {
    return [
      Place(
        id: 'fallback_pyramids',
        name: 'Pyramids of Giza',
        description: 'Iconic ancient pyramids in Giza',
        imageUrl: 'https://images.pexels.com/photos/262786/pexels-photo-262786.jpeg?auto=compress&cs=tinysrgb&w=400',
        latitude: 29.9792,
        longitude: 31.1342,
        category: 'tourist_attraction',
        rating: 4.8,
        constructionHistory: 'Ancient',
        era: 'Pharaonic',
        builder: 'Ancient Egyptians',
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
        imageUrl: 'https://images.pexels.com/photos/208701/pexels-photo-208701.jpeg?auto=compress&cs=tinysrgb&w=400',
        latitude: 30.0478,
        longitude: 31.2336,
        category: 'museum',
        rating: 4.6,
        constructionHistory: 'Modern',
        era: 'Modern',
        builder: 'Unknown',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Historical/Cultural',
        imageUrls: [],
      ),
    ];
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
    } else if ((category == 'cafe' || category == 'restaurant') || nameLower.contains('coffee')) {
      return 'Food & Drink';
    } else if (category == 'shopping_mall' || nameLower.contains('mall')) {
      return 'Malls';
    } else if (category == 'library') {
      return 'Educational';
    }
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 220,
        child: FutureBuilder<List<Place>>(
          future: _mustVisitFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(context).translate('error_loading_recommended_places'),
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => setState(() => _mustVisitFuture = fetchMustVisitPlaces()),
                      child: Text(AppLocalizations.of(context).translate('retry')),
                    ),
                  ],
                ),
              );
            }
            final mustVisitPlaces = snapshot.data ?? [];
            if (mustVisitPlaces.isEmpty) {
              return Center(
                child: Text(
                  AppLocalizations.of(context).translate('no_places_found'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
            }
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: mustVisitPlaces.length,
              itemBuilder: (context, index) {
                final place = mustVisitPlaces[index];
                final isSaved = widget.savedPlaces.contains(place.id);
                return GestureDetector(
                  onTap: () => widget.navigateToPlaceDetails(place),
                  child: Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 4,
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(15),
                                  topRight: Radius.circular(15),
                                ),
                                child: Image.network(
                                  place.imageUrl,
                                  width: double.infinity,
                                  height: 112,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error, size: 50),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      place.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    widget.buildRatingStars(place.rating),
                                    const SizedBox(height: 4),
/*
                                    Text(
                                      place.subCategory,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
*/
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: Icon(
                                isSaved ? Icons.favorite : Icons.favorite_border,
                                color: isSaved ? Colors.red : theme.colorScheme.onSurfaceVariant,
                                size: 24,
                              ),
                              onPressed: () => widget.toggleSavedPlace(place.id),
                              style: IconButton.styleFrom(
                                backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
                                shape: const CircleBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}