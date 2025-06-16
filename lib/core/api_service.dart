import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'http://tourist-api.runasp.net';

  // Save favorites to API
  static Future<bool> saveFavorites(
    String userId,
    List<String> placeIds,
  ) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/User/$userId/favorites'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'favoritePlaces': placeIds}),
    );

    return response.statusCode == 200;
  }

  // Load favorites from API
  static Future<List<String>> loadFavorites(String userId) async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/User/$userId/favorites'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['favoritePlaces'] ?? []);
      }
      throw Exception('API Error: ${response.statusCode}');
    } on TimeoutException {
      throw Exception('Request timed out');
    } on http.ClientException {
      throw Exception('No internet connection');
    }
  }
}
