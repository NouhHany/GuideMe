class Hotel {
  final String placeId;
  final String name;
  final double rating;
  final int? userRatingsTotal;
  final String? vicinity;
  final String? imageUrl;
  final List<String>? openingHours; // Added for opening hours
  final String? priceLevel; // Added as a placeholder for price information

  Hotel({
    required this.placeId,
    required this.name,
    required this.rating,
    this.userRatingsTotal,
    this.vicinity,
    this.imageUrl,
    this.openingHours,
    this.priceLevel,
  });

  factory Hotel.fromJson(Map<String, dynamic> json, {String? apiKey}) {
    return Hotel(
      placeId: json['place_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      rating: (json['rating'] is num ? json['rating'] : 0).toDouble(),
      userRatingsTotal:
          json['user_ratings_total'] is num ? json['user_ratings_total'] : null,
      vicinity: json['vicinity']?.toString(),
      imageUrl:
          (json['photos'] != null &&
                  json['photos'].isNotEmpty &&
                  apiKey != null)
              ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${json['photos'][0]['photo_reference']}&key=$apiKey'
              : null,
      openingHours:
          (json['opening_hours']?['weekday_text'] as List<dynamic>?)
              ?.cast<String>(),
      priceLevel: json['price_level']?.toString(),
    );
  }
}
