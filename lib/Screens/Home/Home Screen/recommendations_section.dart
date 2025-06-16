import 'package:flutter/material.dart';
import '../../../Models/Place.dart';
import '../../../core/AppLocalizations.dart';

class RecommendationsSection extends StatelessWidget {
  final List<Place> recommendedPlaces;
  final List<String> recommendationReasons;
  final bool isLoadingRecommendations;
  final bool hasAttemptedRecommendations;
  final List<Place> favoritePlaces;
  final VoidCallback onRefresh;
  final Function(Place) onNavigateToPlaceDetails;
  final Function(String) onToggleSavedPlace;

  const RecommendationsSection({
    super.key,
    required this.recommendedPlaces,
    required this.recommendationReasons,
    required this.isLoadingRecommendations,
    required this.hasAttemptedRecommendations,
    required this.favoritePlaces,
    required this.onRefresh,
    required this.onNavigateToPlaceDetails,
    required this.onToggleSavedPlace,
  });

  Widget _buildRatingWidget(double rating, BuildContext context) {
    return Text(
      rating.toStringAsFixed(1),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildPlaceCard(BuildContext context, Place place, String reason) {
    final theme = Theme.of(context);
    final isSaved = favoritePlaces.any((favPlace) => favPlace.id == place.id);
    return GestureDetector(
      onTap: () => onNavigateToPlaceDetails(place),
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
                      _buildRatingWidget(place.rating, context),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          reason,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                onPressed: () => onToggleSavedPlace(place.id),
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
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 20.0, 16.0, 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  localizations.translate('recommended_for_you'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                /*TextButton(
                  onPressed: onRefresh,
                  child: Text(
                    localizations.translate('refresh'),
                    style: const TextStyle(color: Color(0xFFD4B087)),
                  ),
                ),*/
              ],
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: isLoadingRecommendations
                ? const Center(child: CircularProgressIndicator())
                : recommendedPlaces.isNotEmpty
                ? PageView.builder(
              itemCount: recommendedPlaces.length,
              padEnds: false,
              pageSnapping: true,
              controller: PageController(
                viewportFraction: 0.45, // Shows ~2.2 cards at a time
                initialPage: 0,
              ),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    width: 160,
                    child: _buildPlaceCard(
                      context,
                      recommendedPlaces[index],
                      recommendationReasons[index],
                    ),
                  ),
                );
              },
            )
                : Center(
              child: Text(
                favoritePlaces.isEmpty
                    ? localizations.translate('add_favorites_to_get_recommendations')
                    : localizations.translate('no_recommendations_available_try_refresh'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}