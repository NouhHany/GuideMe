import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_google_maps_webservices/places.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../Models/Place.dart';
import '../../Services/firestore_service.dart';
import '../../core/AppLocalizations.dart';
import '../Place Details/placedetails.dart';

class _MessageOverlay extends StatelessWidget {
  final String message;
  final bool isError;
  final VoidCallback? onDismiss;

  const _MessageOverlay({
    required this.message,
    required this.isError,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isError
                  ? Colors.red.withOpacity(0.9)
                  : Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Place> _favoritePlaces = [];
  Set<String> _savedPlaceIds = {};
  bool _listView = false;
  bool _isChatbotExpanded = false;
  final ScrollController _controller = ScrollController();
  final ScrollController _gridController = ScrollController();
  final GoogleMapsPlaces placesApi = GoogleMapsPlaces(
    apiKey: 'AIzaSyD3iQPOazh9GfAOl44Y9kDHDJ0zyNqARSA',
  );
  late FirestoreService _firestoreService;
  late final WebViewController _webViewController;
  bool _isChatbotLoading = true;
  String _chatbotErrorMessage = '';
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _firestoreService = FirestoreService(userId: user.uid);
      _loadFavoritePlaces();
    } else {
      _showMessageOverlay('Please sign in to view favorites.');
    }

    _webViewController =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setBackgroundColor(const Color(0x00000000))
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (int progress) {
                if (progress == 100) {
                  setState(() {
                    _isChatbotLoading = false;
                  });
                }
              },
              onPageStarted: (String url) {},
              onPageFinished: (String url) {
                setState(() {
                  _isChatbotLoading = false;
                });
                _webViewController.runJavaScript('''
              document.getElementById('webchat').style.overflow = 'auto';
              document.body.style.overflow = 'auto';
            ''');
              },
              onWebResourceError: (WebResourceError error) {
                setState(() {
                  _isChatbotLoading = false;
                  _chatbotErrorMessage =
                      'Error: ${error.description} (Code: ${error.errorCode})';
                });
              },
              onNavigationRequest: (NavigationRequest request) {
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadHtmlString('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body {
              background-color: transparent;
              margin: 0;
              padding: 0;
              overflow: auto;
            }
            #webchat {
              background-color: transparent !important;
              width: 100%;
              height: 100%;
              overflow: auto;
            }
          </style>
        </head>
        <body>
          <div id="webchat"></div>
          <script src="https://cdn.botpress.cloud/webchat/v3.0/inject.js" defer></script>
          <script src="https://files.bpcontent.cloud/2025/06/16/00/20250616002527-C8N12KER.js" defer></script>
          <script>
            window.botpressWebChat.init({
              "composerPlaceholder": "Ask about your Egypt trip...",
              "botConversationDescription": "Plan your Egypt adventure!",
              "hostUrl": "https://cdn.botpress.cloud/webchat/v3.0",
              "messagingUrl": "https://messaging.botpress.cloud",
              "stylesheet": "https://cdn.botpress.cloud/webchat/v3.0/inject.css",
              "backgroundColor": "transparent"
            });
          </script>
        </body>
        </html>
      ''');
  }

  @override
  void dispose() {
    _controller.dispose();
    _gridController.dispose();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _showMessageOverlay(String message, {bool isError = true}) {
    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder:
          (context) => Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: _MessageOverlay(
              message: message,
              isError: isError,
              onDismiss: () {
                _overlayEntry?.remove();
                _overlayEntry = null;
              },
            ),
          ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    Timer(const Duration(seconds: 3), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  Future<void> _loadFavoritePlaces() async {
    try {
      final places = await _firestoreService.getFavoritePlaces().first;
      setState(() {
        _favoritePlaces = places;
        _savedPlaceIds = places.map((place) => place.id).toSet();
      });
    } catch (e) {
      _showMessageOverlay('Error loading favorite places: $e');
    }
  }

  Future<Place?> _fetchPlaceById(String placeId) async {
    try {
      final response = await placesApi
          .getDetailsByPlaceId(placeId)
          .timeout(const Duration(seconds: 10));
      if (response.isOkay && response.result.geometry?.location != null) {
        final result = response.result;
        return Place(
          id: result.placeId,
          name: result.name,
          description: result.vicinity ?? 'No description available',
          imageUrl:
              result.photos.isNotEmpty
                  ? _getPhotoUrl(result.photos.first.photoReference)
                  : 'https://via.placeholder.com/400',
          latitude: result.geometry!.location.lat,
          longitude: result.geometry!.location.lng,
          category:
              result.types.isNotEmpty
                  ? result.types.first
                  : 'tourist_attraction',
          rating: result.rating?.toDouble() ?? 4.0,
          constructionHistory: 'Unknown',
          era: 'Unknown',
          builder: 'Unknown',
          audioUrl: '',
          indoorMap: [],
          routes: {},
          subCategory: _determineSubCategory(
            result.types.isNotEmpty ? result.types.first : 'unknown',
            result.name,
          ),
          imageUrls: [],
        );
      }
      return null;
    } catch (e) {
      _showMessageOverlay('Error fetching place details: $e');
      return null;
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
    } else if (category == 'cafe' ||
        category == 'restaurant' ||
        nameLower.contains('coffee')) {
      return 'Food & Drink';
    } else if (category == 'shopping_mall' || nameLower.contains('mall')) {
      return 'Malls';
    }
    return 'Other';
  }

  Future<void> _toggleSavedPlace(String placeId) async {
    try {
      final place = await _fetchPlaceById(placeId);
      if (place == null) {
        _showMessageOverlay('Could not find place details.');
        return;
      }
      if (_savedPlaceIds.contains(placeId)) {
        await _firestoreService.removeFavoritePlace(placeId);
        _showMessageOverlay('Removed from favorites.', isError: false);
      } else {
        await _firestoreService.saveFavoritePlace(place);
        _showMessageOverlay('Added to favorites.', isError: false);
      }
      await _loadFavoritePlaces();
    } catch (e) {
      _showMessageOverlay('Error toggling favorite: $e');
    }
  }

  void _navigateToPlaceDetails(Place place) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PlaceDetailsScreen(place: place)),
    );
  }

  Widget _buildRatingWidget(double rating) {
    return Row(
      children: [
        Icon(Icons.star, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceCard(Place place, {bool showFavoriteButton = true}) {
    final isSaved = _savedPlaceIds.contains(place.id);
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _navigateToPlaceDetails(place),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    place.imageUrl,
                    width: double.infinity,
                    height: 112,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 112,
                        color: theme.colorScheme.surfaceContainer,
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 112,
                        color: theme.colorScheme.surfaceContainer,
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      _buildRatingWidget(place.rating),
                    ],
                  ),
                ),
              ],
            ),
            if (showFavoriteButton)
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(
                    isSaved ? Icons.favorite : Icons.favorite_border,
                    color:
                        isSaved
                            ? Colors.red
                            : theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
                  onPressed: () => _toggleSavedPlace(place.id),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.surfaceContainerHighest
                        .withOpacity(0.8),
                    shape: const CircleBorder(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatbotSection(BuildContext context) {
    return _isChatbotExpanded
        ? SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.8,
          child: Stack(
            children: [
              WebViewWidget(controller: _webViewController),
              if (_isChatbotLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Loading chatbot...'),
                    ],
                  ),
                ),
              if (_chatbotErrorMessage.isNotEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _chatbotErrorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Chatbot failed to load. Please check your internet connection or try again later.',
                        style: TextStyle(color: Colors.black, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () {
                    setState(() {
                      _isChatbotExpanded = false;
                    });
                  },
                ),
              ),
            ],
          ),
        )
        : GestureDetector(
          onTap: () {
            setState(() {
              _isChatbotExpanded = true;
            });
          },
          child: Container(
            width: 64,
            height: 64,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFD4B087), Color(0xFF50C9C3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(2, 2),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(-2, -2),
                ),
              ],
            ),
            child: const Icon(
              Icons.support_agent,
              color: Colors.white,
              size: 32,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text(localizations.translate('Favorites'))),
        body: Center(child: Text(localizations.translate('please_sign_in'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations.translate('Favorites'),
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(_listView ? Icons.grid_view : Icons.list),
            onPressed: () {
              setState(() {
                _listView = !_listView;
              });
            },
            tooltip: localizations.translate('toggle_view'),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<Place>>(
            stream: _firestoreService.getFavoritePlaces(),
            builder: (context, favoritePlacesSnapshot) {
              if (favoritePlacesSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (favoritePlacesSnapshot.hasError) {
                return Center(
                  child: Text('Error: ${favoritePlacesSnapshot.error}'),
                );
              }
              _favoritePlaces = favoritePlacesSnapshot.data ?? [];
              _savedPlaceIds = _favoritePlaces.map((place) => place.id).toSet();

              return Scrollbar(
                thumbVisibility: false,
                controller: _controller,
                child: CustomScrollView(
                  controller: _controller,
                  slivers: [
                    if (_favoritePlaces.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.all(12),
                        sliver: SliverToBoxAdapter(
                          child: SingleChildScrollView(
                            controller: _gridController,
                            physics: const ClampingScrollPhysics(),
                            child:
                                _listView
                                    ? Column(
                                      children: List.generate(
                                        _favoritePlaces.length,
                                        (index) {
                                          final place = _favoritePlaces[index];
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4.0,
                                            ),
                                            child: ListTile(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                  ),
                                              leading: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  place.imageUrl,
                                                  width: 50,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => const Icon(
                                                        Icons.error,
                                                      ),
                                                ),
                                              ),
                                              title: Text(
                                                place.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              subtitle: _buildRatingWidget(
                                                place.rating,
                                              ),
                                              trailing: IconButton(
                                                icon: Icon(
                                                  _savedPlaceIds.contains(
                                                        place.id,
                                                      )
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color:
                                                      _savedPlaceIds.contains(
                                                            place.id,
                                                          )
                                                          ? Colors.red
                                                          : Colors.grey,
                                                ),
                                                onPressed:
                                                    () => _toggleSavedPlace(
                                                      place.id,
                                                    ),
                                              ),
                                              onTap:
                                                  () => _navigateToPlaceDetails(
                                                    place,
                                                  ),
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                    : GridView.builder(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.zero,
                                      gridDelegate:
                                          const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 160,
                                            mainAxisSpacing: 12,
                                            crossAxisSpacing: 12,
                                            childAspectRatio: 160 / 260,
                                          ),
                                      itemCount: _favoritePlaces.length,
                                      itemBuilder: (context, index) {
                                        return _buildPlaceCard(
                                          _favoritePlaces[index],
                                        );
                                      },
                                    ),
                          ),
                        ),
                      ),
                    SliverPadding(
                      padding: EdgeInsets.only(
                        bottom:
                            _isChatbotExpanded
                                ? MediaQuery.of(context).size.height * 0.8
                                : 100.0,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Positioned(
            bottom: 0,
            right: _isChatbotExpanded ? 0 : null,
            left: _isChatbotExpanded ? 0 : null,
            child: _buildChatbotSection(context),
          ),
        ],
      ),
    );
  }
}
