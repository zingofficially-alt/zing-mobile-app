import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zing/Service/ThemeProvider.dart';

import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';
import 'package:zing/Widgets/Shared/zing_shimmer.dart';
import 'package:zing/Widgets/Shared/zing_store_card.dart';

class RecommendedStoresRow extends StatelessWidget {
  final String placement;
  final String sectionTitle;
  final CustomUser? user;

  const RecommendedStoresRow({
    super.key,
    required this.placement,
    required this.sectionTitle,
    this.user,
  });

  @override
  Widget build(BuildContext context) {
    final recProvider = Provider.of<RecommendationProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final loading = recProvider.isLoading(placement);
    final resultIds = recProvider.getResults(placement);
    final token = recProvider.getToken(placement);

    // Resolve recommended stores from IDs
    List<Store> stores = recProvider.resolveStores(
        resultIds, storeProvider.activeStores);

    // Fallback: popular stores if recommendations are empty
    if (!loading && stores.isEmpty) {
      stores = recProvider.applyStoreFallback(storeProvider.activeStores, limit: 10);
    }

    if (!loading && stores.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZingSectionTitle(title: sectionTitle),
        SizedBox(
          height: 214,
          child: loading
              ? ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: 3,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ZingShimmer.box(width: 210, height: 196, borderRadius: ZingRadius.lg),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: stores.length,
                  itemBuilder: (ctx, i) => ZingReveal(
                    axis: Axis.horizontal,
                    delay: Duration(milliseconds: 50 * (i % 4)),
                    child: ZingStoreCard(
                      store: stores[i],
                      user: user,
                      rating: stores[i].ratingAvg ?? 0,
                      attributionToken: token,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
