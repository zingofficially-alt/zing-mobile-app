import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zing/Service/ThemeProvider.dart';

import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/StoreProvider.dart';

class RecommendedProductsRow extends StatelessWidget {
  final String placement;
  final String sectionTitle;
  final List<Product> fallbackProducts;

  const RecommendedProductsRow({
    Key? key,
    required this.placement,
    required this.sectionTitle,
    this.fallbackProducts = const [],
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

    // Resolve recommended products from IDs
    List<Product> products = recProvider.resolveProducts(
        resultIds, storeProvider.stores);

    // Fallback: shuffle context products
    if (!loading && products.isEmpty) {
      products =
          recProvider.applyProductFallback(fallbackProducts, limit: 10);
    }

    if (!loading && products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              ZingSpacing.md, 20, ZingSpacing.md, 10),
          child: Text(
            sectionTitle,
            style: theme.textTheme.titleLarge,
          ),
        ),
        SizedBox(
          height: 210,
          child: loading
              ? _buildShimmer(context)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  itemBuilder: (ctx, i) => _buildProductCard(
                      ctx, products[i], token, recProvider),
                ),
        ),
        const SizedBox(height: ZingSpacing.sm),
      ],
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, String token,
      RecommendationProvider recProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final discountedPrice = product.discount != null && product.discount! > 0
        ? product.price * (1 - product.discount! / 100)
        : null;

    return GestureDetector(
      onTap: () {
        recProvider.logEvent(
          eventType: 'detail-page-view',
          productIds: ['product_${product.id}'],
          attributionToken: token,
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: ZingShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: product.imageUrl!,
                      width: 140,
                      height: 110,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _imagePlaceholder(context),
                    )
                  : _imagePlaceholder(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
              child: Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (discountedPrice != null) ...[
                    Text(
                      'Rs ${discountedPrice.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                    Text(
                      'Rs ${product.price.toStringAsFixed(0)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ] else
                    Text(
                      'Rs ${product.price.toStringAsFixed(0)}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
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
      width: 140,
      height: 110,
      color: cs.surfaceContainerHighest,
      child: Icon(Icons.image_outlined, size: 32, color: cs.onSurfaceVariant),
    );
  }

  Widget _buildShimmer(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      scrollDirection: Axis.horizontal,
      itemCount: 4,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: cs.outline,
        highlightColor: cs.surfaceContainerHighest,
        child: Container(
          width: 140,
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
