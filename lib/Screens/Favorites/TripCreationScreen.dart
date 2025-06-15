import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import '../../Models/Place.dart';
import '../../core/AppLocalizations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TripCreationScreen extends StatefulWidget {
  final List<Place> favoritePlaces;
  final Function(String, List<Place>) onTripCreated;

  const TripCreationScreen({super.key, required this.favoritePlaces, required this.onTripCreated});

  @override
  _TripCreationScreenState createState() => _TripCreationScreenState();
}

class _TripCreationScreenState extends State<TripCreationScreen> with SingleTickerProviderStateMixin {
  List<Place> _selectedPlaces = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tripNameController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  final GoogleMapsPlaces _placesApi = GoogleMapsPlaces(apiKey: 'YOUR_GOOGLE_MAPS_API_KEY');
  List<PlacesSearchResult> _searchResults = [];
  List<String> _chatMessages = [];
  bool _isSearching = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final response = await _placesApi.searchByText(query);
      if (response.isOkay) {
        setState(() {
          _searchResults = response.results.where((result) {
            return result.name != null &&
                result.geometry?.location != null &&
                result.rating != null;
          }).toList();
          _isSearching = false;
        });
      } else {
        setState(() {
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _isSearching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error searching places: $e'),
          backgroundColor: Colors.red.withOpacity(0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      );
    }
  }

  Future<void> _getAITripSuggestions(String userInput) async {
    setState(() {
      _chatMessages.add("You: $userInput");
      _isSearching = true;
    });

    try {
      final response = await http.post(
        Uri.parse('https://api.x.ai/v1/grok'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer YOUR_XAI_API_KEY',
        },
        body: jsonEncode({
          'prompt': 'Suggest a travel itinerary for: $userInput',
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiResponse = data['choices'][0]['text'] ?? 'No suggestions found.';
        setState(() {
          _chatMessages.add("AI: $aiResponse");
          _isSearching = false;
        });

        final placeNames = _parseAIResponseForPlaces(aiResponse);
        for (var placeName in placeNames) {
          await _searchPlaces(placeName);
          if (_searchResults.isNotEmpty) {
            _selectedPlaces.add(_convertToPlace(_searchResults.first));
          }
        }
      } else {
        setState(() {
          _chatMessages.add("AI: Error fetching suggestions.");
          _isSearching = false;
        });
      }
    } catch (e) {
      setState(() {
        _chatMessages.add("AI: Error: $e");
        _isSearching = false;
      });
    }
  }

  List<String> _parseAIResponseForPlaces(String aiResponse) {
    return aiResponse.split(',').map((e) => e.trim()).toList();
  }

  Place _convertToPlace(PlacesSearchResult result) {
    return Place(
      id: result.placeId ?? '',
      name: result.name!,
      description: result.vicinity ?? 'No description available',
      imageUrl: result.photos?.isNotEmpty == true
          ? _getPhotoUrl(result.photos!.first.photoReference!)
          : 'https://via.placeholder.com/400',
      latitude: result.geometry!.location.lat,
      longitude: result.geometry!.location.lng,
      category: result.types?.isNotEmpty == true ? result.types!.first : 'tourist_attraction',
      rating: result.rating!.toDouble(),
      constructionHistory: 'Unknown',
      era: 'Unknown',
      builder: 'Unknown',
      audioUrl: '',
      indoorMap: [],
      routes: {},
      subCategory: _determineSubCategory(
        result.types?.isNotEmpty == true ? result.types!.first : 'unknown',
        result.name!,
      ),
      imageUrls: [],
    );
  }

  String _getPhotoUrl(String photoReference) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=YOUR_GOOGLE_MAPS_API_KEY';
  }

  String _determineSubCategory(String category, String name) {
    final nameLower = name.toLowerCase();
    if (category == 'tourist_attraction' ||
        nameLower.contains('tourist') ||
        nameLower.contains('temple') ||
        nameLower.contains('pyramid') ||
        nameLower.contains('museum')) {
      return 'Historical/Cultural';
    } else if (category == 'lodging' || nameLower.contains('hotel')) {
      return 'Hotels';
    } else if (category == 'cafe' || category == 'restaurant' || nameLower.contains('coffee')) {
      return 'Food & Drink';
    } else if (category == 'shopping_mall' || nameLower.contains('mall')) {
      return 'Malls';
    }
    return 'Other';
  }

  void _reorderPlaces(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final place = _selectedPlaces.removeAt(oldIndex);
      _selectedPlaces.insert(newIndex, place);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tripNameController.dispose();
    _chatController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('create_trip') ?? 'Create Trip',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48.0),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFD4B087),
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: Colors.black87,
              unselectedLabelColor: Colors.grey,
              labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
              tabs: [
                Tab(text: localizations.translate('manual_creation') ?? 'Manual Creation'),
                Tab(text: localizations.translate('ai_chatbot') ?? 'AI Chatbot'),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Color(0xFFD4B087)),
            onPressed: _selectedPlaces.isEmpty || _tripNameController.text.isEmpty
                ? null
                : () {
              widget.onTripCreated(_tripNameController.text, _selectedPlaces);
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Manual Creation Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizations.translate('trip_details') ?? 'Trip Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tripNameController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('trip_name') ?? 'Trip Name',
                    hintText: localizations.translate('enter_trip_name') ?? 'Enter trip name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: localizations.translate('search_places') ?? 'Search Places',
                    hintText: localizations.translate('enter_place_name') ?? 'Enter place name',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    suffixIcon: _isSearching
                        ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(),
                    )
                        : IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        _searchPlaces('');
                      },
                    ),
                  ),
                  onChanged: _searchPlaces,
                ),
                const SizedBox(height: 16),
                Text(
                  localizations.translate('select_places') ?? 'Select Places',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 300,
                  child: _searchResults.isNotEmpty
                      ? ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final place = _convertToPlace(_searchResults[index]);
                      final isSelected = _selectedPlaces.contains(place);
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            place.name,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          subtitle: Text(
                            place.subCategory ?? 'Other',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? const Color(0xFFD4B087) : Colors.grey,
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedPlaces.removeWhere((p) => p.id == place.id);
                              } else {
                                _selectedPlaces.add(place);
                              }
                            });
                          },
                        ),
                      );
                    },
                  )
                      : ListView.builder(
                    itemCount: widget.favoritePlaces.length,
                    itemBuilder: (context, index) {
                      final place = widget.favoritePlaces[index];
                      final isSelected = _selectedPlaces.contains(place);
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          title: Text(
                            place.name,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          subtitle: Text(
                            place.subCategory ?? 'Other',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          trailing: Icon(
                            isSelected ? Icons.check_circle : Icons.circle_outlined,
                            color: isSelected ? const Color(0xFFD4B087) : Colors.grey,
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedPlaces.remove(place);
                              } else {
                                _selectedPlaces.add(place);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                if (_selectedPlaces.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    localizations.translate('selected_places') ?? 'Selected Places',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ReorderableListView(
                      scrollDirection: Axis.horizontal,
                      onReorder: _reorderPlaces,
                      children: _selectedPlaces.map((place) {
                        return Card(
                          key: ValueKey(place.id),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Container(
                            width: 120,
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  place.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  textAlign: TextAlign.center,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                  onPressed: () {
                                    setState(() {
                                      _selectedPlaces.remove(place);
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // AI Chatbot Tab
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _chatMessages.length,
                  itemBuilder: (context, index) {
                    final isUserMessage = _chatMessages[index].startsWith("You:");
                    return Align(
                      alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: isUserMessage ? const Color(0xFFD4B087).withOpacity(0.2) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _chatMessages[index],
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _chatController,
                        decoration: InputDecoration(
                          labelText: localizations.translate('ask_ai_for_trip') ?? 'Ask AI for Trip Suggestions',
                          hintText: localizations.translate('enter_prompt') ?? 'Enter your prompt',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                        ),
                        onFieldSubmitted: (value) {
                          if (value.isNotEmpty) {
                            _getAITripSuggestions(value);
                            _chatController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSearching
                          ? null
                          : () {
                        if (_chatController.text.isNotEmpty) {
                          _getAITripSuggestions(_chatController.text);
                          _chatController.clear();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4B087),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: _isSearching
                          ? const CircularProgressIndicator(color: Colors.black87)
                          : const Icon(Icons.send, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              if (_selectedPlaces.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    localizations.translate('selected_places') ?? 'Selected Places',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 120,
                  child: ReorderableListView(
                    scrollDirection: Axis.horizontal,
                    onReorder: _reorderPlaces,
                    children: _selectedPlaces.map((place) {
                      return Card(
                        key: ValueKey(place.id),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Container(
                          width: 120,
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                place.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _selectedPlaces.remove(place);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}