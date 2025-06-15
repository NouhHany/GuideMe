import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';

import 'wiki_summary.dart';
import '../core/AppState.dart'; // Import AppState to access language code

Future<WikiSummary> fetchWikipediaSummary(BuildContext context, String placeName) async {
  try {
    // Get the current language code from AppState
    final appState = Provider.of<AppState>(context, listen: false);
    final languageCode = appState.languageCode ?? 'en'; // Default to English if null

    // Step 1: Search Wikipedia for the place using the selected language
    final searchUrl = Uri.parse(
      'https://$languageCode.wikipedia.org/w/api.php?action=query&list=search&srsearch=${Uri.encodeComponent(placeName)}&format=json',
    );
    final searchResponse = await http.get(searchUrl);

    if (searchResponse.statusCode != 200) {
      throw Exception(
        'Failed to search Wikipedia: ${searchResponse.statusCode}',
      );
    }

    final searchData = jsonDecode(searchResponse.body);
    if (searchData['query']?['search'] == null ||
        searchData['query']['search'].isEmpty) {
      throw Exception('No Wikipedia results found for "$placeName" in $languageCode');
    }

    // Get the top result's title
    final topResultTitle = searchData['query']['search'][0]['title'];

    // Step 2: Fetch the summary for the top result
    final summaryUrl = Uri.parse(
      'https://$languageCode.wikipedia.org/api/rest_v1/page/summary/${Uri.encodeComponent(topResultTitle)}',
    );
    final summaryResponse = await http.get(summaryUrl);

    if (summaryResponse.statusCode != 200) {
      throw Exception(
        'Failed to fetch Wikipedia summary: ${summaryResponse.statusCode}',
      );
    }

    final summaryData = jsonDecode(summaryResponse.body);
    return WikiSummary.fromJson(summaryData);
  } catch (e) {
    print('Error fetching Wikipedia summary: $e');
    // Return a fallback WikiSummary
    return WikiSummary(
      title: placeName,
      extract: 'No available Description $placeName ',
      metadata: {},
      thumbnailUrl: null,
    );
  }
}