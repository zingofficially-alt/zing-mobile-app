import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zing/Service/ThemeProvider.dart';

import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/screen/StoreScreen/StoreScreen.dart';

class RecommendedStoresRow extends StatelessWidget {
  final String placement;
  final String sectionTitle;
  final CustomUser? user;

  const RecommendedStoresRow({
    Key? key,
    required this.placement,
    required this.sectionTitle,
    this.user,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final recProvider = Provider.of<RecommendationProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final loading = recProvider.isLoading(placement);
    final resultIds = recProvider.getResults(placement);
    final token = recProvider.getToken(placement);

    // Resolve recommended stores from IDs
    List<Store> stores = recProvider.resolveStores(
        resultIds, storeProvider.stores);

    // Fallback: popular stores if recommendations are empty
    if (!loading && stores.isEmpty) {
      stores = recProvider.applyStoreFallback(storeProvider.stores, limit: 10);
    }

    if (!loading && stores.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, ZingSpacing.lg, 20, 12),
          child: Text(
            sectionTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 17,
            ),
          ),
        ),
        SizedBox(
          height: 190,
          child: loading
              ? _buildShimmer(context)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.md),
                  scrollDirection: Axis.horizontal,
                  itemCount: stores.length,
                  itemBuilder: (ctx, i) =>
                      _buildStoreCard(ctx, stores[i], token, recProvider),
                ),
        ),
        const SizedBox(height: ZingSpacing.sm),
      ],
    );
  }

  Widget _buildStoreCard(BuildContext context, Store store, String token,
      RecommendationProvider recProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: () {
        // Log interaction event
        recProvider.logEvent(
          eventType: 'detail-page-view',
          productIds: ['store_${store.id}'],
          attributionToken: token,
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreDetailScreen(store: store, user: user),
          ),
        );
      },
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: ZingShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Store image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: store.imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: store.imageUrl,
                      width: 150,
                      height: 100,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _imagePlaceholder(context),
                    )
                  : _imagePlaceholder(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text(
                store.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                store.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Row(
                children: [
                  Icon(Icons.star_rounded,
                      size: 12, color: ZingColors.warning),
                  const SizedBox(width: 2),
                  Text(
                    store.ratings.isEmpty
                        ? '0.0'
                        : (store.ratings
                                    .map((r) => r.score)
                                    .reduce((a, b) => a + b) /
                                store.ratings.length)
                            .toStringAsFixed(1),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 150,
      height: 100,
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.store_outlined,
          size: 32, color: cs.onSurfaceVariant),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.md),
      scrollDirection: Axis.horizontal,
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: cs.outline,
        highlightColor: cs.surfaceContainerHighest,
        child: Container(
          width: 150,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
