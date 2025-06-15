import 'package:flutter/material.dart';

class Place {
  final String name;
  final String address;
  final double? rating;
  final String? openingHours;
  final double? nightlyRate; // Added nightlyRate as an optional field

  Place({
    required this.name,
    required this.address,
    this.rating,
    this.openingHours,
    this.nightlyRate,
  });

  // Factory constructor to create Place from JSON (example implementation)
  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['name'] ?? 'Unknown',
      address: json['vicinity'] ?? 'No address',
      rating: json['rating']?.toDouble(),
      openingHours: json['opening_hours']?['weekday_text']?.join(', ') ?? 'N/A',
      nightlyRate: json['price_level'] != null ? (json['price_level'] * 50.0) : null, // Example logic for nightly rate
    );
  }
}

class GooglePlacesApi {
  Future<Place> fetchPlaceDetails(String placeId) async {
    // Simulate API call with mock data
    return Place(
      name: 'Hotel $placeId',
      address: '123 Street, Alexandria',
      rating: 4.5,
      openingHours: 'Mon-Fri: 9 AM - 5 PM',
      nightlyRate: 100.0,
    );
  }
}

class HotelListScreen extends StatefulWidget {
  @override
  _HotelListScreenState createState() => _HotelListScreenState();
}

class _HotelListScreenState extends State<HotelListScreen> {
  final GooglePlacesApi _api = GooglePlacesApi();
  List<Place> hotels = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHotels();
  }

  Future<void> _fetchHotels() async {
    try {
      // Example: List of place IDs for hotels in Alexandria
      List<String> placeIds = [
        'ChIJ...place_id_1...',
        'ChIJ...place_id_2...',
        // Add more place IDs for hotels in Alexandria
      ];

      List<Place> fetchedHotels = [];
      for (String placeId in placeIds) {
        final place = await _api.fetchPlaceDetails(placeId);
        fetchedHotels.add(place);
      }

      setState(() {
        hotels = fetchedHotels;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching hotels: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hotels in Alexandria')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: hotels.length,
        itemBuilder: (context, index) {
          final hotel = hotels[index];
          return ListTile(
            title: Text(hotel.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Address: ${hotel.address}'),
                Text('Rating: ${hotel.rating?.toString() ?? 'N/A'}'),
                Text('Nightly Rate: \$${hotel.nightlyRate?.toStringAsFixed(2) ?? 'N/A'}'),
                Text('Hours: ${hotel.openingHours ?? 'N/A'}'),
              ],
            ),
          );
        },
      ),
    );
  }
}