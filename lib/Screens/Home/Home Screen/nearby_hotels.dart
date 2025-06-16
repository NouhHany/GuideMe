/*
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:guideme/Models/Place.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/AppLocalizations.dart';

class NearbyHotels extends StatefulWidget {
  final GoogleMapsPlaces places;
  final Function(String) toggleSavedPlace;
  final Set<String> savedPlaces;
  final Function(Place) navigateToPlaceDetails;

  const NearbyHotels({
    super.key,
    required this.places,
    required this.toggleSavedPlace,
    required this.savedPlaces,
    required this.navigateToPlaceDetails,
  });

  @override
  _NearbyHotelsState createState() => _NearbyHotelsState();
}

class _NearbyHotelsState extends State<NearbyHotels> {
  late Future<List<Place>> _nearbyHotelsFuture;

  @override
  void initState() {
    super.initState();
    _nearbyHotelsFuture = fetchNearbyHotels();
  }

  Future<List<Place>> fetchNearbyHotels() async {
    try {
      // Get user's current location
      Position position;
      try {
        position = await _determinePosition();
      } catch (e) {
        print('Location error: $e');
        // Fallback to a default location (e.g., New York City)
        position = Position(
          latitude: 40.7128,
          longitude: -74.0060,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }

      final center = Location(lat: position.latitude, lng: position.longitude);
      // Define search radii to try (in meters)
      final List<int> searchRadii = [5000, 10000, 20000, 50000];
      List<Place> hotels = [];

      // Try each radius until hotels are found or all radii are exhausted
      for (int radius in searchRadii) {
        try {
          final response = await widget.places.searchNearbyWithRadius(
            center,
            radius,
            type: 'lodging', // Use 'lodging' as primary type for broader initial fetch
          );

          print('API Response for radius $radius: ${response.status}');

          if (response.isOkay && response.results.isNotEmpty) {
            for (var result in response.results) {
              // Strictly filter for places with 'hotel' type and rating >= 3.0
              if (result.types != null &&
                  result.types!.contains('hotel') && // Explicitly check for 'hotel'
                  result.rating != null &&
                  result.rating! >= 3.0) {
                hotels.add(
                  Place(
                    id: result.placeId ?? '',
                    name: result.name ?? 'Unnamed Hotel',
                    description: result.vicinity ?? 'No description available',
                    imageUrl: result.photos?.isNotEmpty == true
                        ? _getPhotoUrl(result.photos!.first.photoReference!)
                        : 'https://via.placeholder.com/400x300.png?text=No+Image',
                    latitude: result.geometry?.location.lat ?? position.latitude,
                    longitude: result.geometry?.location.lng ?? position.longitude,
                    category: 'hotel',
                    rating: result.rating?.toDouble() ?? 0.0,
                    constructionHistory: 'Unknown',
                    era: 'Unknown',
                    builder: 'Unknown',
                    audioUrl: '',
                    indoorMap: [],
                    routes: {},
                    imageUrls: [],
                  ),
                );
              }
            }
          }
        } catch (e) {
          print('Error fetching hotels for radius $radius: $e');
        }
        // If sufficient hotels are found (e.g., at least 5), stop searching
        if (hotels.length >= 5) {
          print('Found ${hotels.length} hotels at radius $radius');
          break;
        }
      }

      if (hotels.isEmpty) {
        print('No hotels found after trying all radii');
      }
      return hotels;
    } catch (e) {
      print('Failed to load nearby hotels: $e');
      return []; // Return empty list instead of throwing to handle gracefully in UI
    }
  }

  String _getPhotoUrl(String photoReference) {
    // Replace YOUR_API_KEY with your actual Google Places API key
    // Consider storing this in a secure configuration (e.g., .env file)
    const apiKey = 'YOUR_API_KEY'; // Replace with actual API key
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=$apiKey';
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    // Check location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }

    // Get current position
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              AppLocalizations.of(context).translate('nearby_hotels'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SizedBox(
            height: 220,
            child: FutureBuilder<List<Place>>(
              future: _nearbyHotelsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context).translate('error_loading_nearby_hotels'),
                      style: TextStyle(color: theme.colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final nearbyHotels = snapshot.data ?? [];
                if (nearbyHotels.isEmpty) {
                  return Center(
                    child: Text(
                      AppLocalizations.of(context).translate('no_hotels_found'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: nearbyHotels.length,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemBuilder: (context, index) {
                    final hotel = nearbyHotels[index];
                    final isSaved = widget.savedPlaces.contains(hotel.id);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () => widget.navigateToPlaceDetails(hotel),
                        child: SizedBox(
                          width: 160,
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
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
                                        hotel.imageUrl,
                                        width: double.infinity,
                                        height: 112,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Image.network(
                                          'https://via.placeholder.com/400x300.png?text=No+Image',
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            hotel.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.star,
                                                color: Colors.amber,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                hotel.rating.toStringAsFixed(1),
                                                style: theme.textTheme.bodyMedium?.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
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
                                      isSaved ? Icons.favorite : Icons.favorite_border,
                                      color: isSaved ? Colors.red : theme.colorScheme.onSurfaceVariant,
                                      size: 24,
                                    ),
                                    onPressed: () => widget.toggleSavedPlace(hotel.id),
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
}*/
