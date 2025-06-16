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

      final targetPlaces = [
        {
          'name': 'Auto Vroom Go Karting',
          'query': 'Auto Vroom Go Karting Cairo',
          'lat': 29.9597,
          'lng': 31.2581,
          'type': 'amusement_park',
        },
        {
          'name': 'Museum of Illusions',
          'query': 'Museum of Illusions Cairo',
          'lat': 30.0444,
          'lng': 31.2357,
          'type': 'museum',
        },
        {
          'name': 'Wadi El Hitan',
          'query': 'Wadi El Hitan Fayoum',
          'lat': 29.2708,
          'lng': 30.0111,
          'type': 'tourist_attraction',
        },
        {
          'name': 'Siwa Oasis',
          'query': 'Siwa Oasis',
          'lat': 29.1833,
          'lng': 25.5167,
          'type': 'tourist_attraction',
        },
        {
          'name': 'Wadi El Rayan',
          'query': 'Wadi El Rayan Fayoum',
          'lat': 29.2,
          'lng': 30.4,
          'type': 'tourist_attraction',
        },
        {
          'name': 'Blue Lagoon',
          'query': 'Blue Lagoon Dahab',
          'lat': 28.4947,
          'lng': 34.5153,
          'type': 'tourist_attraction',
        },
        {
          'name': 'Deir al-Muharraq',
          'query': 'Deir al-Muharraq Assiut',
          'lat': 27.3833,
          'lng': 30.8333,
          'type': 'place_of_worship',
        },
        {
          'name': 'Tuna El-Gebel',
          'query': 'Tuna El-Gebel Minya',
          'lat': 27.7351,
          'lng': 30.7041,
          'type': 'tourist_attraction',
        },
        {
          'name': 'Tell Basta',
          'query': 'Tell Basta Zagazig',
          'lat': 30.5736,
          'lng': 31.5147,
          'type': 'tourist_attraction',
        },
        {
          'name': 'El-Qulaan Mangrove Area',
          'query': 'El-Qulaan Marsa Alam',
          'lat': 24.1333,
          'lng': 35.3167,
          'type': 'tourist_attraction',
        },
        {
          'name': 'White Island',
          'query': 'White Island Ras Mohamed',
          'lat': 27.7333,
          'lng': 34.25,
          'type': 'tourist_attraction',
        },
        {
          'name': 'The Bells Hiking Trail',
          'query': 'The Bells Dahab',
          'lat': 28.5,
          'lng': 34.5167,
          'type': 'tourist_attraction',
        },
        {
          'name': 'Manial Palace',
          'query': 'Manial Palace Cairo',
          'lat': 30.0217,
          'lng': 31.2297,
          'type': 'museum',
        },
        {
          'name': 'Bayt Al-Suhaymi',
          'query': 'Bayt Al-Suhaymi Cairo',
          'lat': 30.0525,
          'lng': 31.2625,
          'type': 'tourist_attraction',
        },
        {
          'name': 'Deir el-Medina',
          'query': 'Deir el-Medina Luxor',
          'lat': 25.7286,
          'lng': 32.6017,
          'type': 'tourist_attraction',
        },
        {
          'name': 'Valley of the Nobles',
          'query': 'Valley of the Nobles Luxor',
          'lat': 25.7333,
          'lng': 32.6,
          'type': 'tourist_attraction',
        },
      ];

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
                r.photos.isNotEmpty &&
                r.types.any((t) => excludedTypes.contains(t)) &&
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
            result.placeId,
          );
          if (detailsResponse.isOkay) {
            final details = detailsResponse.result;
            places.add(
              Place(
                id: details.placeId,
                name: details.name,
                description:
                    details.formattedAddress ?? 'No description available',
                imageUrl:
                    details.photos.isNotEmpty == true
                        ? _getPhotoUrl(details.photos.first.photoReference)
                        : 'assets/images/placeholder.jpg',
                latitude: details.geometry?.location.lat ?? lat,
                longitude: details.geometry?.location.lng ?? lng,
                category:
                    details.types.isNotEmpty == true
                        ? details.types.first
                        : type,
                rating: details.rating?.toDouble() ?? minRating,
                constructionHistory: 'Unknown',
                era: 'Unknown',
                builder: 'Unknown',
                audioUrl: '',
                indoorMap: [],
                routes: {},
                subCategory: _determineSubCategory(
                  details.types.isNotEmpty == true ? details.types.first : type,
                  details.name,
                ),
                imageUrls: [],
              ),
            );
          } else {
            places.add(
              Place(
                id: result.placeId,
                name: result.name,
                description: result.vicinity ?? 'No description available',
                imageUrl:
                    result.photos.isNotEmpty == true
                        ? _getPhotoUrl(result.photos.first.photoReference)
                        : 'assets/images/placeholder.jpg',
                latitude: result.geometry?.location.lat ?? lat,
                longitude: result.geometry?.location.lng ?? lng,
                category:
                    result.types.isNotEmpty == true ? result.types.first : type,
                rating: result.rating?.toDouble() ?? minRating,
                constructionHistory: 'Unknown',
                era: 'Unknown',
                builder: 'Unknown',
                audioUrl: '',
                indoorMap: [],
                routes: {},
                subCategory: _determineSubCategory(
                  result.types.isNotEmpty == true ? result.types.first : type,
                  result.name,
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
      Place(
        id: 'fallback_Wadi_El_Hitan',
        name: 'Wadi El Hitan',
        description: 'UNESCO site with ancient whale fossils in Fayoum',
        imageUrl: 'assets/images/wadi_el_hitan_placeholder.jpg',
        latitude: 29.2708,
        longitude: 30.0111,
        category: 'tourist_attraction',
        rating: 4.8,
        constructionHistory: 'Natural',
        era: 'Geological',
        builder: 'Nature',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Natural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_Siwa_Oasis',
        name: 'Siwa Oasis',
        description: 'Remote oasis with ancient ruins and unique culture',
        imageUrl: 'assets/images/siwa_oasis_placeholder.jpg',
        latitude: 29.1833,
        longitude: 25.5167,
        category: 'tourist_attraction',
        rating: 4.8,
        constructionHistory: 'Ancient',
        era: 'Ancient',
        builder: 'Local Tribes',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Natural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_Wadi_El_Rayan',
        name: 'Wadi El Rayan',
        description: 'Stunning desert lakes and waterfalls in Fayoum',
        imageUrl: 'assets/images/wadi_el_rayan_placeholder.jpg',
        latitude: 29.2,
        longitude: 30.4,
        category: 'tourist_attraction',
        rating: 4.7,
        constructionHistory: 'Natural',
        era: 'Modern',
        builder: 'Nature',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Natural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_Blue_Lagoon',
        name: 'Blue Lagoon',
        description: 'Crystal-clear waters perfect for snorkeling in Dahab',
        imageUrl: 'assets/images/blue_lagoon_placeholder.jpg',
        latitude: 28.4947,
        longitude: 34.5153,
        category: 'tourist_attraction',
        rating: 4.9,
        constructionHistory: 'Natural',
        era: 'Natural',
        builder: 'Nature',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Natural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_Deir_al_Muharraq',
        name: 'Deir al-Muharraq',
        description: 'Historic Coptic monastery in Assiut',
        imageUrl: 'assets/images/deir_al_muharraq_placeholder.jpg',
        latitude: 27.3833,
        longitude: 30.8333,
        category: 'place_of_worship',
        rating: 4.5,
        constructionHistory: 'Ancient',
        era: 'Coptic',
        builder: 'Monks',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Historical/Cultural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_Tuna_El_Gebel',
        name: 'Tuna El-Gebel',
        description: 'Ancient necropolis with catacombs in Minya',
        imageUrl: 'assets/images/tuna_el_gebel_placeholder.jpg',
        latitude: 27.7351,
        longitude: 30.7041,
        category: 'tourist_attraction',
        rating: 4.6,
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
        id: 'fallback_Tell_Basta',
        name: 'Tell Basta',
        description: 'Archaeological site of ancient Bubastis in Zagazig',
        imageUrl: 'assets/images/tell_basta_placeholder.jpg',
        latitude: 30.5736,
        longitude: 31.5147,
        category: 'tourist_attraction',
        rating: 4.4,
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
        id: 'fallback_El_Qulaan',
        name: 'El-Qulaan Mangrove Area',
        description: 'Pristine mangrove ecosystem in Marsa Alam',
        imageUrl: 'assets/images/el_qulaan_placeholder.jpg',
        latitude: 24.1333,
        longitude: 35.3167,
        category: 'tourist_attraction',
        rating: 4.7,
        constructionHistory: 'Natural',
        era: 'Natural',
        builder: 'Nature',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Natural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_White_Island',
        name: 'White Island',
        description: 'Stunning coral island in Ras Mohamed',
        imageUrl: 'assets/images/white_island_placeholder.jpg',
        latitude: 27.7333,
        longitude: 34.25,
        category: 'tourist_attraction',
        rating: 4.9,
        constructionHistory: 'Natural',
        era: 'Natural',
        builder: 'Nature',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Natural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_The_Bells',
        name: 'The Bells Hiking Trail',
        description: 'Scenic hiking trail with diving spots in Dahab',
        imageUrl: 'assets/images/the_bells_placeholder.jpg',
        latitude: 28.5,
        longitude: 34.5167,
        category: 'tourist_attraction',
        rating: 4.8,
        constructionHistory: 'Natural',
        era: 'Natural',
        builder: 'Nature',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Adventure',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_Manial_Palace',
        name: 'Manial Palace',
        description: 'Historic royal residence with gardens in Cairo',
        imageUrl: 'assets/images/manial_palace_placeholder.jpg',
        latitude: 30.0217,
        longitude: 31.2297,
        category: 'museum',
        rating: 4.6,
        constructionHistory: 'Modern',
        era: 'Ottoman',
        builder: 'Royal Family',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Historical/Cultural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_Bayt_Al_Suhaymi',
        name: 'Bayt Al-Suhaymi',
        description: 'Restored Ottoman-era house in Cairo',
        imageUrl: 'assets/images/bayt_al_suhaymi_placeholder.jpg',
        latitude: 30.0525,
        longitude: 31.2625,
        category: 'tourist_attraction',
        rating: 4.7,
        constructionHistory: 'Ancient',
        era: 'Ottoman',
        builder: 'Local Nobles',
        audioUrl: '',
        indoorMap: [],
        routes: {},
        subCategory: 'Historical/Cultural',
        imageUrls: [],
      ),
      Place(
        id: 'fallback_Deir_el_Medina',
        name: 'Deir el-Medina',
        description: 'Ancient workers’ village near Luxor',
        imageUrl: 'assets/images/deir_el_medina_placeholder.jpg',
        latitude: 25.7286,
        longitude: 32.6017,
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
        id: 'fallback_Valley_of_the_Nobles',
        name: 'Valley of the Nobles',
        description: 'Tombs of ancient nobles in Luxor',
        imageUrl: 'assets/images/valley_of_the_nobles_placeholder.jpg',
        latitude: 25.7333,
        longitude: 32.6,
        category: 'tourist_attraction',
        rating: 4.7,
        constructionHistory: 'Ancient',
        era: 'Pharaonic',
        builder: 'Ancient Egyptians',
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
    if (nameLower.contains('go karting') ||
        nameLower.contains('hiking') ||
        nameLower.contains('trampoline')) {
      return 'Adventure';
    } else if (category.contains('museum') ||
        nameLower.contains('museum') ||
        nameLower.contains('palace') ||
        nameLower.contains('suhaymi')) {
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
    } else if (category.contains('park') || nameLower.contains('park')) {
      return 'Parks';
    }
    return 'Other';
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
                return PageView.builder(
                  itemCount: hiddenGems.length,
                  padEnds: false,
                  pageSnapping: true,
                  controller: PageController(
                    viewportFraction: 0.45, // Shows ~2.2 cards at a time
                    initialPage: 0,
                  ),
                  itemBuilder: (context, index) {
                    final place = hiddenGems[index];
                    final isSaved = widget.savedPlaces.contains(place.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () => widget.navigateToPlaceDetails(place),
                        child: SizedBox(
                          width: 160,
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
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            height: 112,
                                            color:
                                                theme
                                                    .colorScheme
                                                    .surfaceContainer,
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
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
                                                      theme
                                                          .colorScheme
                                                          .onSurface,
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
                                          // Uncomment to show subCategory
                                          // const SizedBox(height: 4),
                                          // Text(
                                          //   place.subCategory,
                                          //   style: theme.textTheme.bodySmall?.copyWith(
                                          //     color: theme.colorScheme.onSurfaceVariant,
                                          //   ),
                                          // ),
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
