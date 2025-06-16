import 'package:flutter/material.dart';
import 'package:guideme/Models/Place.dart';
import 'package:guideme/Services/firestore_service.dart';
import '../../../core/AppLocalizations.dart';

class LastSeenSection extends StatelessWidget {
  final FirestoreService firestoreService;
  final Function(Place) navigateToPlaceDetails;
  final Function(String) toggleSavedPlace;
  final Set<String> savedPlaces;

  const LastSeenSection({
    super.key,
    required this.firestoreService,
    required this.navigateToPlaceDetails,
    required this.toggleSavedPlace,
    required this.savedPlaces,
  });

  // Method to show a confirmation dialog for deletion with animation
  void _showDeleteDialog(BuildContext context, Place place) {
    final localizations = AppLocalizations.of(context);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) => Container(), // Placeholder
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        final fadeAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeIn,
        );

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: fadeAnimation,
            child: AlertDialog(
              backgroundColor: Theme.of(context).dialogBackgroundColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                localizations.translate('delete_place'),
                style: const TextStyle(color: Color(0xFFD4B087)),
              ),
              content: Text(
                localizations.translate('confirm_delete_place').replaceAll('{placeName}', place.name),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(), // Cancel
                  child: Text(
                    localizations.translate('cancel'),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await firestoreService.deleteRecentPlace(place.id); // Delete from Firestore
                      Navigator.of(context).pop(); // Close dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.translate('place_deleted')),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(localizations.translate('error_deleting_place')),
                        ),
                      );
                    }
                  },
                  child: Text(
                    localizations.translate('delete'),
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              localizations.translate('last_seen'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          StreamBuilder<List<Place>>(
            stream: firestoreService.getRecentPlaces(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    localizations.translate('error_loading_last_seen'),
                  ),
                );
              }
              final recentPlaces = snapshot.data ?? [];
              if (recentPlaces.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      localizations.translate('your_last_seen_places'),
                    ),
                  ),
                );
              }

              return SizedBox(
                height: 220,
                child: PageView.builder(
                  itemCount: recentPlaces.length,
                  padEnds: false,
                  pageSnapping: true,
                  controller: PageController(
                    viewportFraction: 0.45, // Shows ~2.2 cards at a time
                    initialPage: 0,
                  ),
                  itemBuilder: (context, index) {
                    final place = recentPlaces[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: GestureDetector(
                        onTap: () {
                          firestoreService.addRecentPlace(place);
                          navigateToPlaceDetails(place);
                        },
                        onLongPress: () => _showDeleteDialog(context, place), // Show delete dialog on long press
                        child: SizedBox(
                          width: 160,
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
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
                                        loadingBuilder: (
                                            context,
                                            child,
                                            loadingProgress,
                                            ) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return Container(
                                            height: 112,
                                            color: theme.colorScheme.surfaceContainer,
                                            child: const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                          );
                                        },
                                        errorBuilder: (
                                            context,
                                            error,
                                            stackTrace,
                                            ) {
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
                                            style: theme.textTheme.bodyMedium?.copyWith(
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
                                      savedPlaces.contains(place.id)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: savedPlaces.contains(place.id)
                                          ? Colors.red
                                          : theme.colorScheme.onSurfaceVariant,
                                      size: 24,
                                    ),
                                    onPressed: () => toggleSavedPlace(place.id),
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.8),
                                      shape: const CircleBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}