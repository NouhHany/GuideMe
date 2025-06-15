import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../Models/Hotel.dart';
import '../Models/Place.dart';

Future<void> _loadEnv() async {
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    throw Exception('Failed to load .env file: $e');
  }
}

Future<Place> fetchGooglePlaceDetails(String placeId) async {
  await _loadEnv();
  final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    throw Exception('Google Maps API key is missing in .env file');
  }

  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/place/details/json'
    '?place_id=$placeId'
    '&fields=name,place_id,photos,rating,user_ratings_total,geometry,types,editorial_summary,formatted_phone_number,website,opening_hours,business_status'
    '&key=$apiKey',
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['status'] == 'OK' && data['result'] != null) {
      return Place.fromJson(data['result'], apiKey: apiKey);
    } else {
      throw Exception('Google Places API error: ${data['status']}');
    }
  } else {
    throw Exception('Failed to fetch place details: ${response.statusCode}');
  }
}

Future<List<Hotel>> fetchNearbyHotels(double lat, double lng) async {
  await _loadEnv();
  final String apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  if (apiKey.isEmpty) {
    throw Exception('Google Maps API key is missing in .env file');
  }

  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=$lat,$lng'
    '&radius=10000&type=lodging&fields=name,place_id,rating,user_ratings_total,vicinity,photos,opening_hours,price_level&key=$apiKey',
  );

  try {
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK' && data['results'] != null) {
        return (data['results'] as List<dynamic>)
            .map((item) => Hotel.fromJson(item, apiKey: apiKey))
            .toList();
      } else {
        throw Exception('Google Places API error: ${data['status']}');
      }
    } else {
      throw Exception('Failed to fetch nearby hotels: ${response.statusCode}');
    }
  } catch (e) {
    throw Exception('Failed to fetch nearby hotels: $e');
  }
}
