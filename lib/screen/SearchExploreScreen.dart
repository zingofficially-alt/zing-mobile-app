import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Shared/zing_shimmer.dart';
import 'package:zing/Widgets/Shared/zing_store_card.dart';
import 'package:zing/Widgets/Shared/zing_section_header.dart';
import 'package:zing/Widgets/Shared/zing_empty_state.dart';
import 'package:zing/screen/StoreScreen/StoreScreen.dart';

class SearchExploreScreen extends StatefulWidget {
  const SearchExploreScreen({super.key});

  @override
  State<SearchExploreScreen> createState() => _SearchExploreScreenState();
}

class _SearchExploreScreenState extends State<SearchExploreScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  late TabController _tabController;

  String _query = '';
  List<String> _recentSearches = [];
  bool _isSearching = false;

  static const _recentSearchesKey = 'recent_searches';

  final List<_CategoryData> _categories = [
    _CategoryData('Electronics', FontAwesomeIcons.laptop, const Color(0xFF5B7FFF)),
    _CategoryData('Clothing', FontAwesomeIcons.tshirt, const Color(0xFFFF6B6B)),
    _CategoryData('Food', FontAwesomeIcons.utensils, const Color(0xFFFFAE33)),
    _CategoryData('Sports', FontAwesomeIcons.basketballBall, const Color(0xFF43B97F)),
    _CategoryData('Beauty', FontAwesomeIcons.sprayCan, const Color(0xFFD77FE3)),
    _CategoryData('Education', FontAwesomeIcons.graduationCap, const Color(0xFF6C63FF)),
    _CategoryData('Electrical', FontAwesomeIcons.bolt, const Color(0xFFFFA726)),
    _CategoryData('Kids', FontAwesomeIcons.baby, const Color(0xFF4DB6AC)),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
    });
  }

  Future<void> _addRecentSearch(String query) async {
    if (query.trim().isEmpty) return;
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 10) _recentSearches = _recentSearches.sublist(0, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_recentSearchesKey, _recentSearches);
  }

  Future<void> _clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentSearchesKey);
    setState(() => _recentSearches.clear());
  }

  void _onSearch(String value) {
    setState(() {
      _query = value.toLowerCase().trim();
      _isSearching = _query.isNotEmpty;
    });
    if (_isSearching) _addRecentSearch(value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final storeProvider = Provider.of<StoreProvider>(context);
    final userProvider = Provider.of<CustomUserProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(ZingSpacing.md, ZingSpacing.md, ZingSpacing.md, 0),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search, color: cs.onSurfaceVariant, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        onChanged: (v) => setState(() {
                          _query = v.toLowerCase().trim();
                          _isSearching = _query.isNotEmpty;
                        }),
                        onSubmitted: _onSearch,
                        decoration: InputDecoration(
                          hintText: 'Search stores, products...',
                          hintStyle: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    if (_isSearching)
                      IconButton(
                        icon: Icon(Icons.close, color: cs.onSurfaceVariant, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _isSearching = false;
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: _isSearching
                  ? _buildSearchResults(storeProvider, userProvider.user, theme)
                  : _buildExplorePage(storeProvider, userProvider.user, theme),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplorePage(StoreProvider storeProvider, CustomUser? user, ThemeData theme) {
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: ZingSpacing.xl),
      children: [
        // Recent searches
        if (_recentSearches.isNotEmpty) ...[
          ZingSectionHeader(
            title: 'Recent Searches',
            actionText: 'Clear',
            onAction: _clearRecentSearches,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.lg),
            child: Wrap(
              spacing: ZingSpacing.sm,
              runSpacing: ZingSpacing.sm,
              children: _recentSearches.map((search) {
                return ActionChip(
                  label: Text(search),
                  avatar: Icon(Icons.history, size: 16, color: cs.onSurfaceVariant),
                  onPressed: () {
                    _searchController.text = search;
                    _onSearch(search);
                  },
                );
              }).toList(),
            ),
          ),
        ],

        // Categories
        ZingSectionHeader(
          title: 'Categories',
          icon: Icons.category_rounded,
          iconColor: cs.primary,
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.lg),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final cat = _categories[index];
            return GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _searchController.text = cat.name;
                _onSearch(cat.name);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cat.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: FaIcon(cat.icon, color: cat.color, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        cat.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Trending stores
        ZingSectionHeader(
          title: 'Trending Stores',
          icon: Icons.trending_up_rounded,
          iconColor: cs.secondary,
        ),
        if (storeProvider.isLoading)
          SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              itemBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ZingShimmer.box(width: 188, height: 240, borderRadius: 20),
              ),
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: storeProvider.stores.length.clamp(0, 10),
              itemBuilder: (context, index) {
                final store = storeProvider.stores[index];
                return ZingStoreCard(store: store, user: user);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResults(StoreProvider storeProvider, CustomUser? user, ThemeData theme) {
    final cs = theme.colorScheme;

    // Filter stores
    final matchedStores = storeProvider.stores.where((store) {
      return store.name.toLowerCase().contains(_query) ||
          store.category.toLowerCase().contains(_query);
    }).toList();

    // Filter products across all stores
    final matchedProducts = <MapEntry<Store, Product>>[];
    for (final store in storeProvider.stores) {
      for (final product in store.products) {
        if (product.name.toLowerCase().contains(_query)) {
          matchedProducts.add(MapEntry(store, product));
        }
      }
    }

    if (matchedStores.isEmpty && matchedProducts.isEmpty) {
      return ZingEmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results found',
        subtitle: 'Try adjusting your search term',
      );
    }

    return Column(
      children: [
        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurfaceVariant,
          indicatorColor: cs.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: 'Stores (${matchedStores.length})'),
            Tab(text: 'Products (${matchedProducts.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Stores tab
              matchedStores.isEmpty
                  ? const ZingEmptyState(
                      icon: Icons.storefront_outlined,
                      title: 'No stores found',
                      subtitle: 'Try a different search term',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(ZingSpacing.md),
                      itemCount: matchedStores.length,
                      itemBuilder: (context, index) {
                        final store = matchedStores[index];
                        return _buildStoreListItem(store, user, theme);
                      },
                    ),
              // Products tab
              matchedProducts.isEmpty
                  ? const ZingEmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products found',
                      subtitle: 'Try a different search term',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(ZingSpacing.md),
                      itemCount: matchedProducts.length,
                      itemBuilder: (context, index) {
                        final entry = matchedProducts[index];
                        return _buildProductListItem(entry.key, entry.value, user, theme);
                      },
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoreListItem(Store store, CustomUser? user, ThemeData theme) {
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreDetailScreen(store: store, user: user),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ZingShadows.soft,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: store.imageUrl.isNotEmpty
                  ? Image.network(store.imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _storePlaceholder(cs))
                  : _storePlaceholder(cs),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(store.category, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _buildProductListItem(Store store, Product product, CustomUser? user, ThemeData theme) {
    final cs = theme.colorScheme;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StoreDetailScreen(store: store, user: user),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ZingShadows.soft,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                  ? Image.network(product.imageUrl!, width: 60, height: 60, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _productPlaceholder(cs))
                  : _productPlaceholder(cs),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text('Rs ${product.price.toStringAsFixed(0)}',
                    style: theme.textTheme.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w700)),
                  Text('from ${store.name}', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }

  Widget _storePlaceholder(ColorScheme cs) => Container(
    width: 60, height: 60,
    color: cs.primary.withOpacity(0.08),
    child: Icon(Icons.storefront_rounded, color: cs.primary.withOpacity(0.3), size: 24),
  );

  Widget _productPlaceholder(ColorScheme cs) => Container(
    width: 60, height: 60,
    color: cs.primary.withOpacity(0.08),
    child: Icon(Icons.inventory_2_outlined, color: cs.primary.withOpacity(0.3), size: 24),
  );
}

class _CategoryData {
  final String name;
  final FaIconData icon;
  final Color color;
  const _CategoryData(this.name, this.icon, this.color);
}
