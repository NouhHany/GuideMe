import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:geolocator/geolocator.dart';
import 'package:guideme/Models/Place.dart';

import '../../../core/AppLocalizations.dart';

class HiddenGems extends StatefulWidget {
  final GoogleMapsPlaces placesApi;
  final Function(String) toggleSavedPlace;
  final Set<String> savedPlaces;
  final Function(Place) navigateToPlaceDetails;
  final Widget Function(double) buildRatingStars;
  final Position? userLocation;

  const HiddenGems({
    super.key,
    required this.placesApi,
    required this.toggleSavedPlace,
    required this.savedPlaces,
    required this.navigateToPlaceDetails,
    required this.buildRatingStars,
    this.userLocation,
  });

  @override
  _HiddenGemsState createState() => _HiddenGemsState();
}

class _HiddenGemsState extends State<HiddenGems> {
  late Future<List<Place>> _hiddenGemsFuture;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _hiddenGemsFuture = _fetchHiddenGems();
  }

  Future<List<Place>> _fetchHiddenGems() async {
    try {
      if (widget.userLocation == null) {
        return _getFallbackPlaces();
      }

      // Fetch places from Firestore
      final QuerySnapshot querySnapshot =
          await FirebaseFirestore.instance.collection('hidden_gems').get();
      final targetPlaces =
          querySnapshot.docs
              .map(
                (doc) => {
                  'name': doc['name'] as String,
                  'query': doc['query'] as String,
                  'lat': doc['lat'] as double,
                  'lng': doc['lng'] as double,
                  'type': doc['type'] as String,
                },
              )
              .toList();

      List<Place> places = [];
      const excludedTypes = [
        'store',
        'business_service',
        'restaurant',
        'lodging',
      ];
      const blacklistedNames = ['Mix Phone', 'شركة الحداد', 'Ahmed Elhamrawy'];
      const minRating = 4.0;

      for (var place in targetPlaces) {
        final query = place['query'] as String;
        final name = place['name'] as String;
        final type = place['type'] as String;
        final lat = place['lat'] as double;
        final lng = place['lng'] as double;

        final response = await widget.placesApi.searchByText(
          query,
          location: Location(lat: lat, lng: lng),
          radius: 50000,
          type: type,
          region: 'eg', // Restrict to Egypt
        );

        if (response.isOkay && response.results.isNotEmpty) {
          final result = response.results.firstWhere(
            (r) =>
                r.name.toLowerCase().contains(name.toLowerCase()) &&
                r.rating != null &&
                r.rating! >= minRating &&
                r.photos != null &&
                r.photos!.isNotEmpty &&
                r.types != null &&
                !r.types!.any((t) => excludedTypes.contains(t)) &&
                !blacklistedNames.any(
                  (n) => r.name.toLowerCase().contains(n.toLowerCase()),
                ),
            orElse:
                () => response.results.firstWhere(
                  (r) => r.name.toLowerCase().contains(name.toLowerCase()),
                  orElse: () => response.results.first,
                ),
          );

          final detailsResponse = await widget.placesApi.getDetailsByPlaceId(
            result.placeId!,
          );
          if (detailsResponse.isOkay) {
            final details = detailsResponse.result;
            places.add(
              Place(
                id: details.placeId ?? 'fallback_$name',
                name: details.name ?? name,
                description:
                    details.formattedAddress ?? 'No description available',
                imageUrl:
                    details.photos?.isNotEmpty == true
                        ? _getPhotoUrl(details.photos!.first.photoReference!)
                        : 'assets/images/placeholder.jpg',
                latitude: details.geometry?.location.lat ?? lat,
                longitude: details.geometry?.location.lng ?? lng,
                category:
                    details.types?.isNotEmpty == true
                        ? details.types!.first
                        : type,
                rating: details.rating?.toDouble() ?? minRating,
                constructionHistory: 'Unknown',
                era: 'Unknown',
                builder: 'Unknown',
                audioUrl: '',
                indoorMap: [],
                routes: {},
                subCategory: _determineSubCategory(
                  details.types?.isNotEmpty == true
                      ? details.types!.first
                      : type,
                  details.name ?? name,
                ),
                imageUrls: [],
              ),
            );
          } else {
            places.add(
              Place(
                id: result.placeId ?? 'fallback_$name',
                name: result.name ?? name,
                description: result.vicinity ?? 'No description available',
                imageUrl:
                    result.photos?.isNotEmpty == true
                        ? _getPhotoUrl(result.photos!.first.photoReference!)
                        : 'assets/images/placeholder.jpg',
                latitude: result.geometry?.location.lat ?? lat,
                longitude: result.geometry?.location.lng ?? lng,
                category:
                    result.types?.isNotEmpty == true
                        ? result.types!.first
                        : type,
                rating: result.rating?.toDouble() ?? minRating,
                constructionHistory: 'Unknown',
                era: 'Unknown',
                builder: 'Unknown',
                audioUrl: '',
                indoorMap: [],
                routes: {},
                subCategory: _determineSubCategory(
                  result.types?.isNotEmpty == true ? result.types!.first : type,
                  result.name ?? name,
                ),
                imageUrls: [],
              ),
            );
          }
        }
      }

      // Sort by proximity to user location if available
      if (widget.userLocation != null) {
        places.sort(
          (a, b) => Geolocator.distanceBetween(
            widget.userLocation!.latitude,
            widget.userLocation!.longitude,
            a.latitude,
            a.longitude,
          ).compareTo(
            Geolocator.distanceBetween(
              widget.userLocation!.latitude,
              widget.userLocation!.longitude,
              b.latitude,
              b.longitude,
            ),
          ),
        );
      }

      return places.isNotEmpty ? places : _getFallbackPlaces();
    } catch (e, stackTrace) {
      debugPrint('Error fetching hidden gems: $e\nStack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Error loading Hidden Gems';
      });
      return _getFallbackPlaces();
    }
  }

  List<Place> _getFallbackPlaces() {
    return [
      Place(
        id: 'fallback_Auto_Vroom',
        name: 'Auto Vroom Go Karting',
        description: 'Thrilling go-karting experience in Cairo',
        imageUrl: 'assets/images/auto_vroom_placeholder.jpg',
        latitude: 29.9597,
        longitude: 31.2581,
        category: 'amusement_park',
        rating: 4.5,
        constructionHistory: 'Modern',
        era: 'Modern',
        builder: 'Private',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Adventure',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_Museum_of_Illusions',
        name: 'Museum of Illusions',
        description: 'Interactive museum with mind-bending exhibits in Cairo',
        imageUrl: 'assets/images/museum_illusions_placeholder.jpg',
        latitude: 30.0444,
        longitude: 31.2357,
        category: 'museum',
        rating: 4.6,
        constructionHistory: 'Modern',
        era: 'Modern',
        builder: 'Private',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Cultural',
        imageUrls: [],
      ),
      // Add other fallback places as needed
    ];
  }

  String _getPhotoUrl(String photoReference) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=AIzaSyD3iQPOazh9GfAOl44Y9kDHDJ0zyNqARSA';
  }

  String _determineSubCategory(String category, String name) {
    final nameLower = name.toLowerCase();
    if (nameLower.contains('go karting') || nameLower.contains('hiking')) {
      return 'Adventure';
    } else if (category.contains('museum') || nameLower.contains('palace')) {
      return 'Cultural';
    } else if (category.contains('place_of_worship') ||
        nameLower.contains('deir') ||
        nameLower.contains('monastery') ||
        nameLower.contains('basta') ||
        nameLower.contains('medina') ||
        nameLower.contains('nobles') ||
        nameLower.contains('gebel')) {
      return 'Historical/Cultural';
    } else if (category.contains('natural_feature') ||
        nameLower.contains('oasis') ||
        nameLower.contains('desert') ||
        nameLower.contains('lagoon') ||
        nameLower.contains('wadi') ||
        nameLower.contains('mangrove') ||
        nameLower.contains('island')) {
      return 'Natural';
    } else if (category.contains('park')) {
      return 'Parks';
    }
    return 'Other'; // Fallback for unclassified types
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              localizations.translate('Hidden_gems'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: FutureBuilder<List<Place>>(
              future: _hiddenGemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError || _errorMessage != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage ??
                              localizations.translate(
                                'error_loading_recommended_places',
                              ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed:
                              () => setState(
                                () => _hiddenGemsFuture = _fetchHiddenGems(),
                              ),
                          child: Text(localizations.translate('retry')),
                        ),
                      ],
                    ),
                  );
                }
                final hiddenGems = snapshot.data ?? [];
                if (hiddenGems.isEmpty) {
                  return Center(
                    child: Text(
                      localizations.translate('no_places_found'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: hiddenGems.length,
                  itemBuilder: (context, index) {
                    final place = hiddenGems[index];
                    final isSaved = widget.savedPlaces.contains(place.id);
                    return GestureDetector(
                      onTap: () => widget.navigateToPlaceDetails(place),
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 12),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(16),
                                    ),
                                    child: Image.network(
                                      place.imageUrl,
                                      width: double.infinity,
                                      height: 112,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (
                                        context,
                                        child,
                                        loadingProgress,
                                      ) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Container(
                                          height: 112,
                                          color:
                                              theme
                                                  .colorScheme
                                                  .surfaceContainer,
                                          child: const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      },
                                      errorBuilder: (
                                        context,
                                        error,
                                        stackTrace,
                                      ) {
                                        debugPrint(
                                          'Image load error for ${place.name} (URL: ${place.imageUrl}): $error',
                                        );
                                        return Container(
                                          height: 112,
                                          color:
                                              theme
                                                  .colorScheme
                                                  .surfaceContainer,
                                          child: Icon(
                                            Icons.broken_image,
                                            size: 40,
                                            color:
                                                theme
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          place.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                                color:
                                                    theme.colorScheme.onSurface,
                                              ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          place.rating.toStringAsFixed(1),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
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
                                    isSaved
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color:
                                        isSaved
                                            ? Colors.red
                                            : theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                    size: 24,
                                  ),
                                  onPressed:
                                      () => widget.toggleSavedPlace(place.id),
                                  style: IconButton.styleFrom(
                                    backgroundColor: theme
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.8),
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
        ],
      ),
    );
  }
}
