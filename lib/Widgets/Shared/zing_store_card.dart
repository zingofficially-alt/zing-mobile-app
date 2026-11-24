import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/screen/StoreScreen/StoreScreen.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';

/// Opens a store page with the iOS push and logs the view for recommendations.
void openStore(BuildContext context, Store store, {CustomUser? user, String? attributionToken}) {
  Provider.of<RecommendationProvider>(context, listen: false).logEvent(
    eventType: 'detail-page-view',
    productIds: ['store_${store.id}'],
    attributionToken: attributionToken,
  );
  Navigator.of(context).push(zingRoute(StoreDetailScreen(store: store, user: user)));
}

/// Store card in two layouts:
/// * compact (default) — a 200pt-wide card for horizontal rows;
/// * [wide] — a full-width hero card with a parallax photo, for vertical lists.
class ZingStoreCard extends StatelessWidget {
  final Store store;
  final CustomUser? user;
  final double? distance;
  final double rating;
  final bool wide;

  /// Recommendation attribution, logged when the card is opened.
  final String? attributionToken;

  const ZingStoreCard({
    this.attributionToken,
    super.key,
    required this.store,
    this.user,
    this.distance,
    this.rating = 0.0,
    this.wide = false,
  });

  String get _distanceLabel {
    final d = distance;
    if (d == null) return store.category;
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return wide ? _buildWide(context) : _buildCompact(context);
  }

  Widget _image(ColorScheme cs) {
    if (store.imageUrl.isEmpty) return _placeholder(cs);
    return CachedNetworkImage(
      imageUrl: store.imageUrl,
      fit: BoxFit.cover,
      fadeInDuration: ZingMotion.medium,
      placeholder: (_, __) => ColoredBox(color: cs.surfaceContainerHighest),
      errorWidget: (_, __, ___) => _placeholder(cs),
    );
  }

  Widget _placeholder(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.primary.withValues(alpha: 0.18), cs.secondary.withValues(alpha: 0.14)],
        ),
      ),
      child: Icon(CupertinoIcons.bag, color: cs.primary.withValues(alpha: 0.45), size: 40),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = store.openStatus();

    return ZingPressable(
      onTap: () => openStore(context, store, user: user, attributionToken: attributionToken),
      child: Container(
        width: 210,
        margin: const EdgeInsets.fromLTRB(6, 4, 6, 14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZingRadius.lg),
          boxShadow: ZingShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _image(cs),
                  Positioned(top: 10, right: 10, child: _FavouriteButton(storeId: store.id)),
                  if (rating > 0)
                    Positioned(left: 10, bottom: 10, child: _RatingChip(rating: rating)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: ZingType.headline(cs.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (status != null) ...[
                        _OpenDot(open: status.isOpen),
                        const SizedBox(width: 5),
                      ],
                      Expanded(
                        child: Text(
                          distance == null ? store.category : '${store.category} · $_distanceLabel',
                          style: ZingType.footnote(cs.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWide(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = store.openStatus();

    return ZingPressable(
      pressedScale: 0.97,
      onTap: () => openStore(context, store, user: user, attributionToken: attributionToken),
      child: Container(
        height: 236,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(ZingRadius.xl - 4),
          boxShadow: ZingShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ZingParallax(child: _image(cs)),
            // Legibility scrim for the caption.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0x14000000), Color(0xB3000000)],
                  stops: [0.35, 0.55, 1],
                ),
              ),
            ),
            Positioned(top: 14, right: 14, child: _FavouriteButton(storeId: store.id)),
            Positioned(
              top: 14,
              left: 14,
              child: ZingGlass(
                borderRadius: BorderRadius.circular(100),
                color: Colors.black,
                opacity: 0.28,
                blur: 14,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Text(
                    store.category.toUpperCase(),
                    style: ZingType.style(11, weight: FontWeight.w700, color: Colors.white, letterSpacing: 0.6),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          store.name,
                          style: ZingType.title2(Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (status != null) ...[
                              _OpenDot(open: status.isOpen),
                              const SizedBox(width: 6),
                              Text(status.isOpen ? 'Open' : 'Closed',
                                  style: ZingType.subhead(Colors.white.withValues(alpha: 0.92))),
                              Text('  ·  ', style: ZingType.subhead(Colors.white70)),
                            ],
                            Flexible(
                              child: Text(
                                distance != null ? _distanceLabel : store.description,
                                style: ZingType.subhead(Colors.white.withValues(alpha: 0.92)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (rating > 0) ...[
                    const SizedBox(width: 12),
                    _RatingChip(rating: rating, large: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpenDot extends StatelessWidget {
  final bool open;
  const _OpenDot({required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? ZingColors.success : ZingColors.error;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4)],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  final double rating;
  final bool large;
  const _RatingChip({required this.rating, this.large = false});

  @override
  Widget build(BuildContext context) {
    return ZingGlass(
      borderRadius: BorderRadius.circular(100),
      color: Colors.white,
      opacity: 0.88,
      blur: 12,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: large ? 10 : 8, vertical: large ? 6 : 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.star_fill, color: ZingColors.warning, size: large ? 15 : 12),
            const SizedBox(width: 4),
            Text(
              rating.toStringAsFixed(1),
              style: ZingType.style(large ? 14 : 12, weight: FontWeight.w700, color: ZingColors.textDark),
            ),
          ],
        ),
      ),
    );
  }
}

/// Heart toggle on a frosted circle. Bounces when switched on.
class _FavouriteButton extends StatelessWidget {
  final String? storeId;
  const _FavouriteButton({required this.storeId});

  @override
  Widget build(BuildContext context) {
    final id = storeId;
    if (id == null) return const SizedBox.shrink();
    return Consumer<CustomUserProvider>(
      builder: (context, userProvider, _) {
        if (userProvider.user == null) return const SizedBox.shrink();
        final isFavorite = userProvider.isFavoriteStore(id);
        return GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            if (isFavorite) {
              userProvider.removeFavoriteStore(id);
            } else {
              userProvider.addFavoriteStore(id);
            }
          },
          child: ZingGlass(
            borderRadius: BorderRadius.circular(100),
            color: Colors.white,
            opacity: 0.86,
            blur: 12,
            child: SizedBox(
              width: 34,
              height: 34,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(isFavorite),
                tween: Tween(begin: isFavorite ? 0.5 : 1, end: 1),
                duration: const Duration(milliseconds: 500),
                curve: Curves.elasticOut,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: Icon(
                  isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
                  color: isFavorite ? ZingColors.secondary : ZingColors.textDark,
                  size: 18,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
