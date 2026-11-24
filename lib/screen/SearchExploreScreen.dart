import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/screen/StoreScreen/StoreScreen.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';
import 'package:zing/Widgets/Shared/zing_shimmer.dart';
import 'package:zing/Widgets/Shared/zing_store_card.dart';

enum _ResultKind { stores, products }

enum _StoreFilter { openNow, delivers, topRated }

class SearchExploreScreen extends StatefulWidget {
  /// Focus the search field straight away (when opened from Home).
  final bool autofocus;
  const SearchExploreScreen({super.key, this.autofocus = false});

  @override
  State<SearchExploreScreen> createState() => _SearchExploreScreenState();
}

class _SearchExploreScreenState extends State<SearchExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  String _query = '';
  List<String> _recentSearches = [];
  _ResultKind _kind = _ResultKind.stores;
  final Set<_StoreFilter> _filters = {};
  // Stores: 0 best match, 1 highest rated, 2 name. Products: 0 best match, 1 price up, 2 price down.
  int _sort = 0;

  static bool _passes(Store s, _StoreFilter f) {
    switch (f) {
      case _StoreFilter.openNow:
        return s.openStatus()?.isOpen ?? false;
      case _StoreFilter.delivers:
        return (s.deliveryOptions ?? const []).any((o) => o.contains('Home Delivery'));
      case _StoreFilter.topRated:
        return (s.ratingAvg ?? 0) >= 4;
    }
  }

  void _pickSort() {
    final labels = _kind == _ResultKind.stores
        ? const ['Best Match', 'Highest Rated', 'Name A–Z']
        : const ['Best Match', 'Price: Low to High', 'Price: High to Low'];
    showZingActionSheet(
      context,
      title: 'Sort by',
      actions: [
        for (var i = 0; i < labels.length; i++)
          ZingSheetAction(
            label: labels[i],
            isDefault: i == _sort,
            onPressed: () => setState(() => _sort = i),
          ),
      ],
    );
  }

  static const _recentSearchesKey = 'recent_searches';

  static const _categories = [
    _CategoryData('Electronics', 'assets/images/electronics.jpg', Color(0xFF5856D6)),
    _CategoryData('Clothing', 'assets/images/clothing.jpg', Color(0xFFFF2D55)),
    _CategoryData('Food', 'assets/images/food.jpg', Color(0xFFFF9500)),
    _CategoryData('Sports', 'assets/images/sports.jpg', Color(0xFF34C759)),
    _CategoryData('Beauty', 'assets/images/beauty.jpg', Color(0xFFAF52DE)),
    _CategoryData('Education', 'assets/images/education.jpg', Color(0xFF007AFF)),
    _CategoryData('Electrical', 'assets/images/electrical.jpg', Color(0xFFFF9F0A)),
    _CategoryData('Kids', 'assets/images/kids.jpg', Color(0xFF32ADE6)),
  ];

  bool get _searching => _query.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _searchFocus.requestFocus();
        });
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _recentSearches = prefs.getStringList(_recentSearchesKey) ?? []);
    } catch (_) {}
  }

  Future<void> _addRecentSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() {
      _recentSearches
        ..remove(q)
        ..insert(0, q);
      if (_recentSearches.length > 8) _recentSearches = _recentSearches.sublist(0, 8);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    if (mounted) setState(() => _recentSearches = []);
  }

  void _setQuery(String value, {bool remember = false}) {
    setState(() => _query = value.toLowerCase().trim());
    if (remember) _addRecentSearch(value);
  }

  void _searchFor(String value) {
    _searchController.text = value;
    _searchFocus.unfocus();
    _setQuery(value, remember: true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final storeProvider = Provider.of<StoreProvider>(context);
    final user = Provider.of<CustomUserProvider>(context).user;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: GestureDetector(
        onTap: () => _searchFocus.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            CupertinoSliverNavigationBar(
              largeTitle: const Text('Explore'),
              automaticallyImplyLeading: false,
              leading: canPop
                  ? CupertinoNavigationBarBackButton(
                      color: cs.primary,
                      onPressed: () => Navigator.of(context).maybePop(),
                    )
                  : null,
              backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.82),
              border: null,
              stretch: true,
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedSearchBar(
                background: theme.scaffoldBackgroundColor,
                child: ZingSearchField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  placeholder: 'Stores, products, categories',
                  onChanged: (v) => _setQuery(v),
                  onSubmitted: (v) => _setQuery(v, remember: true),
                ),
              ),
            ),
            if (_searching)
              ..._buildResults(storeProvider, user)
            else
              ..._buildExplore(storeProvider, user),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 96)),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- explore

  List<Widget> _buildExplore(StoreProvider storeProvider, CustomUser? user) {
    final cs = Theme.of(context).colorScheme;
    final trending = [...storeProvider.activeStores]
      ..sort((a, b) => (b.ratingAvg ?? 0).compareTo(a.ratingAvg ?? 0));

    return [
      if (_recentSearches.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: ZingSectionTitle(
            title: 'Recent',
            actionLabel: 'Clear',
            onAction: _clearRecentSearches,
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _recentSearches)
                  ZingPill(label: s, icon: CupertinoIcons.clock, onTap: () => _searchFor(s)),
              ],
            ),
          ),
        ),
      ],
      const SliverToBoxAdapter(child: ZingSectionTitle(title: 'Browse Categories')),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.45,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, i) {
            final c = _categories[i];
            final count = storeProvider.activeStores.where((s) => s.category == c.name).length;
            return ZingReveal(
              delay: Duration(milliseconds: 40 * (i % 2)),
              child: ZingPressable(
                onTap: () => _searchFor(c.name),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(ZingRadius.lg),
                    boxShadow: ZingShadows.soft,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ZingParallax(
                        extent: 0.35,
                        child: Image.asset(c.image, fit: BoxFit.cover),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [c.color.withValues(alpha: 0.05), c.color.withValues(alpha: 0.85)],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(c.name, style: ZingType.headline(Colors.white)),
                            Text(
                              count == 1 ? '1 store' : '$count stores',
                              style: ZingType.footnote(Colors.white.withValues(alpha: 0.85)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SliverToBoxAdapter(child: ZingSectionTitle(title: 'Top Rated')),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 214,
          child: storeProvider.isLoading
              ? ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 3,
                  itemBuilder: (_, __) => Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ZingShimmer.box(width: 210, height: 196, borderRadius: ZingRadius.lg),
                  ),
                )
              : trending.isEmpty
                  ? Center(
                      child: Text('No stores yet', style: ZingType.subhead(cs.onSurfaceVariant)))
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: trending.length.clamp(0, 10),
                      itemBuilder: (context, i) => ZingReveal(
                        axis: Axis.horizontal,
                        delay: Duration(milliseconds: 50 * (i % 4)),
                        child: ZingStoreCard(
                          store: trending[i],
                          user: user,
                          rating: trending[i].ratingAvg ?? 0,
                        ),
                      ),
                    ),
        ),
      ),
    ];
  }

  // ------------------------------------------------------------- results

  List<Widget> _buildResults(StoreProvider storeProvider, CustomUser? user) {
    // Everything that matches the words typed, before filters.
    final matched = storeProvider.activeStores
        .where((s) =>
            s.name.toLowerCase().contains(_query) ||
            s.category.toLowerCase().contains(_query) ||
            s.description.toLowerCase().contains(_query))
        .toList();
    final stores = matched.where((s) => _filters.every((f) => _passes(s, f))).toList();
    if (_sort == 1) {
      stores.sort((a, b) => (b.ratingAvg ?? 0).compareTo(a.ratingAvg ?? 0));
    } else if (_sort == 2) {
      stores.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final products = <MapEntry<Store, Product>>[
      for (final store in storeProvider.activeStores)
        if (_filters.every((f) => _passes(store, f)))
          for (final p in store.products)
            if (p.name.toLowerCase().contains(_query) ||
                (p.description ?? '').toLowerCase().contains(_query))
              MapEntry(store, p),
    ];
    if (_sort == 1) {
      products.sort((a, b) => a.value.effectivePrice.compareTo(b.value.effectivePrice));
    } else if (_sort == 2) {
      products.sort((a, b) => b.value.effectivePrice.compareTo(a.value.effectivePrice));
    }

    // Counts show how many matched stores each filter would keep.
    int keeps(_StoreFilter f) => matched.where((s) => _passes(s, f)).length;
    const filterLabels = {
      _StoreFilter.openNow: 'Open Now',
      _StoreFilter.delivers: 'Delivers',
      _StoreFilter.topRated: 'Top Rated',
    };

    final showingStores = _kind == _ResultKind.stores;
    final count = showingStores ? stores.length : products.length;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: ZingSegmented<_ResultKind>(
            value: _kind,
            segments: {
              _ResultKind.stores: 'Stores (${stores.length})',
              _ResultKind.products: 'Products (${products.length})',
            },
            onChanged: (k) => setState(() {
              _kind = k;
              _sort = 0;
            }),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 46,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            children: [
              ZingPill(
                label: _sort == 0 ? 'Sort' : 'Sorted',
                icon: CupertinoIcons.arrow_up_arrow_down,
                selected: _sort != 0,
                onTap: _pickSort,
              ),
              for (final f in _StoreFilter.values) ...[
                const SizedBox(width: 8),
                ZingPill(
                  label: '${filterLabels[f]} (${keeps(f)})',
                  selected: _filters.contains(f),
                  onTap: () => setState(() => _filters.contains(f) ? _filters.remove(f) : _filters.add(f)),
                ),
              ],
            ],
          ),
        ),
      ),
      if (count == 0)
        SliverToBoxAdapter(
          child: Column(
            children: [
              _NoResults(query: _searchController.text.trim(), filtered: _filters.isNotEmpty),
              if (_filters.isNotEmpty)
                CupertinoButton(
                  onPressed: () => setState(_filters.clear),
                  child: Text('Clear Filters',
                      style: ZingType.body(Theme.of(context).colorScheme.primary)),
                ),
            ],
          ),
        )
      else
        SliverToBoxAdapter(
          child: AnimatedSwitcher(
            duration: ZingMotion.medium,
            switchInCurve: ZingMotion.emphasized,
            transitionBuilder: (child, a) => FadeTransition(
              opacity: a,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.02), end: Offset.zero).animate(a),
                child: child,
              ),
            ),
            child: ZingGroupedSection(
              key: ValueKey('$_kind-$_query-$_sort-${_filters.length}'),
              separatorIndent: 84,
              children: showingStores
                  ? [for (final s in stores) _StoreResultRow(store: s, user: user)]
                  : [
                      for (final e in products)
                        _ProductResultRow(store: e.key, product: e.value, user: user),
                    ],
            ),
          ),
        ),
    ];
  }
}

class _PinnedSearchBar extends SliverPersistentHeaderDelegate {
  final Widget child;
  final Color background;
  _PinnedSearchBar({required this.child, required this.background});

  @override
  double get minExtent => 56;
  @override
  double get maxExtent => 56;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: background, child: child);

  @override
  bool shouldRebuild(_PinnedSearchBar old) => old.child != child || old.background != background;
}

class _ResultThumb extends StatelessWidget {
  final String? url;
  final IconData fallback;
  const _ResultThumb({required this.url, required this.fallback});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final placeholder = Container(
      color: cs.primary.withValues(alpha: 0.1),
      child: Icon(fallback, color: cs.primary.withValues(alpha: 0.5), size: 24),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 56,
        height: 56,
        child: url == null || url!.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, __) => ColoredBox(color: cs.surfaceContainerHighest),
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class _StoreResultRow extends StatelessWidget {
  final Store store;
  final CustomUser? user;
  const _StoreResultRow({required this.store, this.user});

  @override
  Widget build(BuildContext context) {
    final status = store.openStatus();
    return ZingListRow(
      leading: _ResultThumb(url: store.imageUrl, fallback: CupertinoIcons.bag),
      title: store.name,
      subtitle: [
        store.category,
        if (status != null) status.isOpen ? 'Open' : 'Closed',
        if ((store.ratingAvg ?? 0) > 0) '★ ${store.ratingAvg!.toStringAsFixed(1)}',
      ].join(' · '),
      onTap: () => openStore(context, store, user: user),
    );
  }
}

class _ProductResultRow extends StatelessWidget {
  final Store store;
  final Product product;
  final CustomUser? user;
  const _ProductResultRow({required this.store, required this.product, this.user});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ZingListRow(
      leading: _ResultThumb(url: product.imageUrl, fallback: CupertinoIcons.cube_box),
      title: product.name,
      subtitle: 'from ${store.name}',
      trailing: Text(
        'Rs ${product.price.toStringAsFixed(0)}',
        style: ZingType.style(15, weight: FontWeight.w600, color: cs.primary),
      ),
      onTap: () =>
          Navigator.of(context).push(zingRoute(StoreDetailScreen(store: store, user: user))),
    );
  }
}

class _NoResults extends StatelessWidget {
  final String query;
  final bool filtered;
  const _NoResults({required this.query, this.filtered = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ZingReveal(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 48, 40, 0),
        child: Column(
          children: [
            Icon(CupertinoIcons.search, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.45)),
            const SizedBox(height: 14),
            Text('No Results for “$query”',
                style: ZingType.title3(cs.onSurface), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(filtered ? 'Your filters may be hiding some results.' : 'Check the spelling or try a new search.',
                style: ZingType.subhead(cs.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CategoryData {
  final String name;
  final String image;
  final Color color;
  const _CategoryData(this.name, this.image, this.color);
}
