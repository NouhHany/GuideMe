/*
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:geolocator/geolocator.dart';

class NearbyPhotoAnimator extends StatefulWidget {
  final Position? userLocation;
  final double height;
  final List<String> placeTypes;
  final List<String> excludedPlaceTypes;
  final double minRating;

  const NearbyPhotoAnimator({
    super.key,
    required this.userLocation,
    required this.height,
    required this.placeTypes,
    required this.excludedPlaceTypes,
    required this.minRating,
  });

  @override
  _NearbyPhotoAnimatorState createState() => _NearbyPhotoAnimatorState();
}

class _NearbyPhotoAnimatorState extends State<NearbyPhotoAnimator> {
  List<PlacesSearchResult> _nearbyPlaces = [];

  @override
  void initState() {
    super.initState();
    _fetchNearbyPlaces();
  }

  Future<void> _fetchNearbyPlaces() async {
    if (widget.userLocation == null) return;

    final places = GoogleMapsPlaces(apiKey: 'YOUR_API_KEY'); // Replace with your API key
    final location = Location(
      lat: widget.userLocation!.latitude,
      lng: widget.userLocation!.longitude,
    );
    final response = await places.searchNearbyWithRadius(
      location,
      5000, // 5 km radius
      type: widget.placeTypes.isNotEmpty ? widget.placeTypes.join('|') : null,
    );

    if (response.isOkay && response.results != null) {
      setState(() {
        _nearbyPlaces = response.results.where((place) {
          final isExcluded = widget.excludedPlaceTypes.any((type) => place.types.contains(type));
          final hasRating = place.rating != null && place.rating! >= widget.minRating;
          final isDesired = widget.placeTypes.isEmpty || widget.placeTypes.any((type) => place.types.contains(type));
          return !isExcluded && hasRating && isDesired;
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _nearbyPlaces.length,
        itemBuilder: (context, index) {
          final place = _nearbyPlaces[index];
          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              width: 200,
              color: Colors.grey,
              child: Center(child: Text(place.name)),
            ),
          );
        },
      ),
    );
  }
}*/
/**/
