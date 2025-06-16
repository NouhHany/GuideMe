

class Place {
  final String id;
  final String? placeId;
  final String name;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String category;
  final double rating;
  final int? userRatingsTotal; // Added for total number of reviews
  final String constructionHistory;
  final String era;
  final String builder;
  final List<String> imageUrls;
  final String audioUrl;
  final List<Map<String, dynamic>> indoorMap;
  final Map<String, String> routes;
  final String? subCategory;
  final String? summary;
  final String? phoneNumber;
  final String? website;
  final List<String>? openingHours;
  final String? businessStatus;
  final List<String>? types; // Explicitly store all place types

  Place({
    required this.id,
    this.placeId,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.category,
    required this.rating,
    this.userRatingsTotal,
    required this.constructionHistory,
    required this.era,
    required this.builder,
    required this.imageUrls,
    required this.audioUrl,
    required this.indoorMap,
    required this.routes,
    this.subCategory,
    this.summary,
    this.phoneNumber,
    this.website,
    this.openingHours,
    this.businessStatus,
    this.types,
  });

  factory Place.fromJson(Map<String, dynamic> json, {String? apiKey}) {
    bool isValidUrl(String? url) =>
        url != null &&
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));

    return Place(
      id: json['id']?.toString() ?? json['place_id']?.toString() ?? '',
      placeId: json['place_id']?.toString(),
      name: json['name']?.toString() ?? 'Unknown',
      description:
          json['editorial_summary']?['overview']?.toString() ??
          json['description']?.toString() ??
          'No description available',
      imageUrl:
          (json['photos'] != null &&
                  json['photos'].isNotEmpty &&
                  apiKey != null)
              ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${json['photos'][0]['photo_reference']}&key=$apiKey'
              : isValidUrl(json['imageUrl'])
              ? json['imageUrl']
              : '',
      latitude:
          (json['geometry']?['location']?['lat'] is num
                  ? json['geometry']['location']['lat']
                  : json['latitude'] is num
                  ? json['latitude']
                  : 0)
              .toDouble(),
      longitude:
          (json['geometry']?['location']?['lng'] is num
                  ? json['geometry']['location']['lng']
                  : json['longitude'] is num
                  ? json['longitude']
                  : 0)
              .toDouble(),
      category:
          json['types']?.isNotEmpty == true
              ? json['types'][0].toString().replaceAll('_', ' ').toLowerCase()
              : json['category']?.toString() ?? 'Unknown',
      rating: (json['rating'] is num ? json['rating'] : 0).toDouble(),
      userRatingsTotal:
          json['user_ratings_total'] is num ? json['user_ratings_total'] : null,
      constructionHistory:
          json['constructionHistory']?.toString() ??
          json['construction_history']?.toString() ??
          json['history']?.toString() ??
          'Unknown',
      era: json['era']?.toString() ?? json['period']?.toString() ?? 'Unknown',
      builder:
          json['builder']?.toString() ??
          json['architect']?.toString() ??
          'Unknown',
      imageUrls:
          (json['photos'] as List<dynamic>?)
              ?.map(
                (photo) =>
                    apiKey != null
                        ? 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=${photo['photo_reference']}&key=$apiKey'
                        : '',
              )
              .where(isValidUrl)
              .toList() ??
          (json['imageUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .where(isValidUrl)
              .toList() ??
          [],
      audioUrl: json['audioUrl']?.toString() ?? '',
      indoorMap:
          (json['indoorMap'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
          [],
      routes: Map<String, String>.from(json['routes'] ?? {}),
      subCategory: json['types']?.join(', ') ?? json['subCategory']?.toString(),
      summary: json['editorial_summary']?['overview']?.toString(),
      phoneNumber: json['formatted_phone_number']?.toString(),
      website: json['website']?.toString(),
      openingHours:
          (json['opening_hours']?['weekday_text'] as List<dynamic>?)
              ?.cast<String>(),
      businessStatus: json['business_status']?.toString(),
      types: (json['types'] as List<dynamic>?)?.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'place_id': placeId,
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'rating': rating,
      'user_ratings_total': userRatingsTotal,
      'constructionHistory': constructionHistory,
      'era': era,
      'builder': builder,
      'imageUrls': imageUrls,
      'audioUrl': audioUrl,
      'indoorMap': indoorMap,
      'routes': routes,
      'subCategory': subCategory,
      'summary': summary,
      'phoneNumber': phoneNumber,
      'website': website,
      'openingHours': openingHours,
      'businessStatus': businessStatus,
      'types': types,
    };
  }

  // Factory method to create a placeholder Place
  factory Place.placeholder(String id) {
    return Place(
      id: id,
      name: 'Unknown',
      description: 'No description available',
      imageUrl: 'https://via.placeholder.com/400',
      latitude: 0.0,
      longitude: 0.0,
      category: 'Unknown',
      rating: 0.0,
      constructionHistory: 'Unknown',
      era: 'Unknown',
      builder: 'Unknown',
      imageUrls: [],
      audioUrl: '',
      indoorMap: [],
      routes: {},
    );
  }
}
