import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:guideme/Models/Place.dart';
import 'package:guideme/Services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/AppLocalizations.dart';
import '../Place Details/placedetails.dart';

class SearchScreen extends StatefulWidget {
  final List<Place> places;
  final bool isDarkMode;
  final String languageCode;
  final ScrollController scrollController;
  final Function(bool)? onThemeToggle;
  final Function(String)? onLanguageChange;

  const SearchScreen({
    super.key,
    this.places = const [],
    this.isDarkMode = false,
    this.languageCode = 'en',
    this.onThemeToggle,
    this.onLanguageChange,
    required this.scrollController,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late List<Place> _filteredPlaces;
  final TextEditingController _searchController = TextEditingController();
  final GoogleMapsPlaces placesApi = GoogleMapsPlaces(
    apiKey: 'AIzaSyD3iQPOazh9GfAOl44Y9kDHDJ0zyNqARSA',
  );
  String _selectedCategory = 'All';
  String _selectedGovernorate = 'All';
  double _minRating = 0.0;
  bool _listView = true;
  List<String> _searchHistory = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _filteredPlaces = widget.places;
    _searchController.addListener(_performSearch);
    widget.scrollController.addListener(_scrollListener);
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    widget.scrollController.removeListener(_scrollListener);
    super.dispose();
  }

  void _scrollListener() {}

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList('search_history') ?? [];
      if (mounted) {
        setState(() {
          _searchHistory = history;
        });
      }
    } catch (e) {
      _showSnackBar('Error loading search history: $e');
    }
  }

  Future<void> _saveSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final newHistory = List<String>.from(_searchHistory);
      if (newHistory.contains(query)) {
        newHistory.remove(query);
      }
      newHistory.insert(0, query);
      if (newHistory.length > 10) {
        newHistory.removeLast();
      }
      await prefs.setStringList('search_history', newHistory);
      if (mounted) {
        setState(() {
          _searchHistory = newHistory;
        });
      }
    } catch (e) {
      _showSnackBar('Error saving search history: $e');
    }
  }

  Future<void> _removeSearchHistoryItem(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newHistory = List<String>.from(_searchHistory)..remove(query);
      await prefs.setStringList('search_history', newHistory);
      if (mounted) {
        setState(() {
          _searchHistory = newHistory;
        });
      }
    } catch (e) {
      _showSnackBar('Error removing search history: $e');
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _filteredPlaces = widget.places;
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await placesApi.searchByText(
        query,
        location: Location(lat: 26.8206, lng: 30.8025), // Egypt center
        radius: 50000,
      );

      if (response.isOkay) {
        final places = response.results.map((result) {
          return Place(
            id: result.placeId,
            name: result.name,
            description: result.vicinity ?? 'No description available',
            imageUrl: result.photos.isNotEmpty == true
                ? _getPhotoUrl(result.photos.first.photoReference)
                : 'https://via.placeholder.com/400',
            latitude: result.geometry?.location.lat ?? 0.0,
            longitude: result.geometry?.location.lng ?? 0.0,
            category: result.types.isNotEmpty == true
                ? result.types.first
                : 'tourist_attraction',
            rating: result.rating?.toDouble() ?? 0.0,
            constructionHistory: 'Unknown',
            era: 'Unknown',
            builder: 'Unknown',
            audioUrl: '',
            indoorMap: [],
            routes: {},
            subCategory: _determineSubCategory(
              result.types.first,
              result.name,
            ),
            imageUrls: [],
          );
        }).toList();

        setState(() {
          _filteredPlaces = _filterPlacesByCriteria(places);
          _isLoading = false;
          _errorMessage = _filteredPlaces.isEmpty ? 'No places found' : null;
        });
      } else {
        setState(() {
          _filteredPlaces = _filterPlacesByCriteria(widget.places);
          _isLoading = false;
          _errorMessage = 'Error searching places';
        });
      }
    } catch (e) {
      setState(() {
        _filteredPlaces = _filterPlacesByCriteria(widget.places);
        _isLoading = false;
        _errorMessage = 'Error loading your search';
      });
    }
  }

  String _getPhotoUrl(String photoReference) {
    return 'https://maps.googleapis.com/maps/api/place/photo?maxwidth=400&photoreference=$photoReference&key=AIzaSyD3iQPOazh9GfAOl44Y9kDHDJ0zyNqARSA';
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
    } else if ((category == 'cafe' || category == 'restaurant') ||
        nameLower.contains('coffee')) {
      return 'Food & Drink';
    } else if (category == 'shopping_mall' || nameLower.contains('mall')) {
      return 'Malls';
    } else if (category == 'library') {
      return 'Educational';
    }
    return 'Other';
  }

  List<Place> _filterPlacesByCriteria(List<Place> places) {
    final query = _searchController.text.toLowerCase();
    return places.where((place) {
      bool matchesQuery = query.isEmpty ||
          place.name.toLowerCase().contains(query) ||
          place.description.toLowerCase().contains(query);
      bool matchesCategory =
          _selectedCategory == 'All' || place.subCategory == _selectedCategory;
      bool matchesGovernorate = _selectedGovernorate == 'All' ||
          place.description.toLowerCase().contains(
            _selectedGovernorate.toLowerCase(),
          );
      bool matchesRating = place.rating >= _minRating;
      return matchesQuery && matchesCategory && matchesGovernorate && matchesRating;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = 'All';
      _selectedGovernorate = 'All';
      _minRating = 0.0;
      _searchController.clear();
      _filteredPlaces = widget.places;
      _errorMessage = null;
    });
  }

  void _navigateToPlaceDetails(Place place) {
    _saveSearchHistory(place.name);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final firestoreService = FirestoreService(userId: user.uid);
      firestoreService.addRecentPlace(place).catchError((e) {
        _showSnackBar('Error saving recent place: $e');
      });
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlaceDetailsScreen(place: place)),
    );
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildRatingStars(double rating) {
    return Row(
      children: [
        Row(
          children: List.generate(5, (index) {
            return Icon(
              index < rating.floor() ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 16,
            );
          }),
        ),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final governorates = [
      'All',
      'Alexandria',
      'Aswan',
      'Asyut',
      'Beheira',
      'Beni Suef',
      'Cairo',
      'Dakahlia',
      'Damietta',
      'Faiyum',
      'Gharbia',
      'Giza',
      'Ismailia',
      'Kafr El Sheikh',
      'Luxor',
      'Matruh',
      'Minya',
      'Monufia',
      'New Valley',
      'North Sinai',
      'Port Said',
      'Qalyubia',
      'Qena',
      'Red Sea',
      'Sharqia',
      'Sohag',
      'South Sinai',
      'Suez',
    ];
    final categories = [
      'All',
      'Historical/Cultural',
      'Food & Drink',
      'Hotels',
      'Malls',
      'Educational',
      'Other',
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
          tooltip: localizations.translate('back'),
        ),
        title: Text(
          localizations.translate('search'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_listView ? Icons.grid_view_rounded : Icons.list_rounded),
            onPressed: () => setState(() => _listView = !_listView),
            tooltip: localizations.translate('toggle_view'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  style: TextStyle(color: Colors.black87),
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: localizations.translate('search_for_a_place_ellipsis'),
                    hintStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch();
                      },
                    )
                        : null,
                    filled: true,
                    fillColor: widget.isDarkMode ? Colors.black87 : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  keyboardType: TextInputType.text,
                  onSubmitted: (query) {
                    _performSearch();
                    _saveSearchHistory(query);
                  },
                ),
              ),
              if (_searchHistory.isNotEmpty)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _searchHistory.length,
                    itemBuilder: (context, index) {
                      final query = _searchHistory[index];
                      return Dismissible(
                        key: Key(query),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _removeSearchHistoryItem(query),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete_forever_rounded, color: Colors.white),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            label: Text(query, style: const TextStyle(fontSize: 12)),
                            onPressed: () {
                              _searchController.text = query;
                              _performSearch();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.translate('category'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: categories.map((category) {
                        final isSelected = _selectedCategory == category;
                        return ChoiceChip(
                          label: Text(category),
                          selected: isSelected,
                          selectedColor: const Color(0xFFD4B087),
                          onSelected: (selected) {
                            setState(() {
                              _selectedCategory = selected ? category : 'All';
                              _performSearch();
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    Text(localizations.translate('governorate'), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    DropdownButton<String>(
                      value: _selectedGovernorate,
                      isExpanded: true,
                      items: governorates.map((governorate) {
                        return DropdownMenuItem(value: governorate, child: Text(governorate));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedGovernorate = value!;
                          _performSearch();
                          debugPrint('Selected governorate: $_selectedGovernorate');
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(localizations.translate('minimum_rating'), style: Theme.of(context).textTheme.titleMedium),
                    Slider(
                      value: _minRating,
                      min: 0.0,
                      max: 5.0,
                      divisions: 10,
                      label: _minRating.toStringAsFixed(1),
                      activeColor: const Color(0xFFD4B087),
                      onChanged: (value) {
                        setState(() {
                          _minRating = value;
                          _performSearch();
                        });
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _resetFilters,
                        child: Text(
                          localizations.translate('clear_filters'),
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                      ElevatedButton(
                        onPressed: _performSearch,
                        child: Text(localizations.translate('retry')),
                      ),
                    ],
                  ),
                )
                    : _filteredPlaces.isEmpty
                    ? Center(
                  child: Text(
                    localizations.translate('no_places_found'),
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                )
                    : _listView
                    ? ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredPlaces.length,
                  itemBuilder: (context, index) {
                    final place = _filteredPlaces[index];
                    return ListTile(
                      leading: CachedNetworkImage(
                        imageUrl: place.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => const Icon(Icons.error),
                      ),
                      title: Text(place.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRatingStars(place.rating),
                          const SizedBox(height: 4),
                          Icon(Icons.volume_up, size: 16, color: Colors.grey[600]),
                        ],
                      ),
                      onTap: () => _navigateToPlaceDetails(place),
                    );
                  },
                )
                    : GridView.builder(
                  controller: widget.scrollController,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredPlaces.length,
                  itemBuilder: (context, index) {
                    final place = _filteredPlaces[index];
                    return GestureDetector(
                      onTap: () => _navigateToPlaceDetails(place),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 4,
                        child: Column(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                                child: CachedNetworkImage(
                                  imageUrl: place.imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey[300],
                                    child: const Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.error, size: 50),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Text(
                                    place.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  _buildRatingStars(place.rating),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}