import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:guideme/Models/Place.dart';
import 'package:guideme/Screens/Place%20Details/placedetails.dart';
import 'package:guideme/Services/firestore_service.dart';
import '../../../core/AppLocalizations.dart';

class GovernoratePlacesScreen extends StatefulWidget {
  final String governorate;
  final Future<List<Place>> Function(String) fetchPlaces;
  final Function(String) toggleSavedPlace;
  final Set<String> savedPlaces;

  const GovernoratePlacesScreen({
    super.key,
    required this.governorate,
    required this.fetchPlaces,
    required this.toggleSavedPlace,
    required this.savedPlaces,
  });

  @override
  _GovernoratePlacesScreenState createState() => _GovernoratePlacesScreenState();
}

class _GovernoratePlacesScreenState extends State<GovernoratePlacesScreen> {
  late Future<List<Place>> _placesFuture;

  @override
  void initState() {
    super.initState();
    _placesFuture = widget.fetchPlaces(widget.governorate);
  }

  void _navigateToPlaceDetails(Place place) {
    try {
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
    } catch (e) {
      _showSnackBar(AppLocalizations.of(context).translate('error_navigating_to_place_details') + ': $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.governorate,
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Place>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(localizations.translate('error_loading_places')),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _placesFuture = widget.fetchPlaces(widget.governorate);
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          } else if (snapshot.data!.isEmpty) {
            return Center(child: Text('No places found for ${widget.governorate}'));
          }

          final places = snapshot.data!.where((place) => place.rating != 0.0).toList();
          if (places.isEmpty) {
            return Center(child: Text('No rated places found for ${widget.governorate}'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 160,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 160 / 220,
            ),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              final isSaved = widget.savedPlaces.contains(place.id);
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
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                                Text(
                                  place.rating.toStringAsFixed(1),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: IconButton(
                          icon: Icon(
                            isSaved ? Icons.favorite : Icons.favorite_border,
                            color: isSaved ? Colors.red : theme.colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          onPressed: () {
                            widget.toggleSavedPlace(place.id);
                            setState(() {});
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
                            shape: const CircleBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}