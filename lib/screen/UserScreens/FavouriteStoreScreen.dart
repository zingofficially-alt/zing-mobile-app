import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';
import 'package:zing/Widgets/Shared/zing_store_card.dart';

/// The stores the customer has hearted. Tapping the heart on a card removes
/// it straight away; the list updates live.
class FavouriteStoreScreen extends StatelessWidget {
  /// Kept for older callers; the back button shows whenever the page was pushed.
  final bool showAppBar;

  const FavouriteStoreScreen({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final userProvider = Provider.of<CustomUserProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final user = userProvider.user;
    final ids = user?.favorites ?? const <String>[];
    final stores = storeProvider.stores.where((s) => ids.contains(s.id)).toList();

    return ZingLargeTitlePage(
      title: 'Favourites',
      showBack: true,
      onRefresh: () async {
        await userProvider.fetchUserDetails();
        await storeProvider.fetchStores();
      },
      slivers: [
        if (storeProvider.isLoading)
          const SliverFillRemaining(hasScrollBody: false, child: ZingSpinner())
        else if (stores.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 0, 40, 120),
              child: ZingReveal(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: ZingColors.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.heart, size: 44, color: ZingColors.secondary),
                    ),
                    const SizedBox(height: 22),
                    Text('No favourites yet', style: ZingType.title2(cs.onSurface)),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the heart on any store to keep it here for next time.',
                      style: ZingType.subhead(cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                '${stores.length} saved ${stores.length == 1 ? 'store' : 'stores'}',
                style: ZingType.subhead(cs.onSurfaceVariant),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: stores.length,
            itemBuilder: (context, i) => ZingReveal(
              key: ValueKey(stores[i].id),
              delay: Duration(milliseconds: 50 * (i % 3)),
              child: ZingStoreCard(
                wide: true,
                store: stores[i],
                user: user,
                rating: stores[i].ratingAvg ?? 0,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
