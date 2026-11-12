import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/screen/StoreScreen/StoreScreen.dart';

class ZingStoreCard extends StatelessWidget {
  final Store store;
  final CustomUser? user;
  final double? distance;
  final double rating;

  const ZingStoreCard({
    super.key,
    required this.store,
    this.user,
    this.distance,
    this.rating = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Provider.of<RecommendationProvider>(context, listen: false).logEvent(
          eventType: 'detail-page-view',
          productIds: ['store_${store.id}'],
        );
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                StoreDetailScreen(store: store, user: user),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 0.04),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                  child: child,
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 300),
          ),
        );
      },
      child: Container(
        width: 188,
        margin: const EdgeInsets.symmetric(horizontal: ZingSpacing.sm, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ZingShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store image
                SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      store.imageUrl.isNotEmpty
                          ? Image.network(
                              store.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(cs),
                            )
                          : _buildPlaceholder(cs),
                      // Gradient overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black.withOpacity(0.15)],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                      // Rating badge
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: ZingShadows.soft,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: ZingColors.warning, size: 14),
                              const SizedBox(width: 3),
                              Text(
                                rating.toStringAsFixed(1),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Store info
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: theme.textTheme.titleMedium?.copyWith(height: 1.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(Icons.place_rounded, color: cs.onSurfaceVariant, size: 13),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              distance != null
                                  ? '${distance!.toStringAsFixed(1)} km away'
                                  : 'Distance N/A',
                              style: theme.textTheme.bodySmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.09),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          store.category,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Favourite button
            Positioned(
              top: 10,
              right: 10,
              child: Consumer<CustomUserProvider>(
                builder: (context, userProvider, _) {
                  final isFavorite = userProvider.isFavoriteStore(store.id!);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (isFavorite) {
                        userProvider.removeFavoriteStore(store.id!);
                      } else {
                        userProvider.addFavoriteStore(store.id!);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: isFavorite ? cs.secondary : cs.surface,
                        shape: BoxShape.circle,
                        boxShadow: ZingShadows.soft,
                      ),
                      child: Icon(
                        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFavorite ? Colors.white : cs.onSurfaceVariant,
                        size: 16,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme cs) {
    return Container(
      color: cs.primary.withOpacity(0.08),
      child: Icon(Icons.storefront_rounded, color: cs.primary.withOpacity(0.3), size: 40),
    );
  }
}
