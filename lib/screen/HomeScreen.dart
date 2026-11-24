import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/screen/NotificationsScreen.dart';
import 'package:zing/screen/SearchExploreScreen.dart';
import 'package:zing/Service/AdvertisementProvider.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/NotificationProvider.dart';
import 'package:zing/Service/OfferProvider.dart';
import 'package:zing/Service/RecentStores.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Recommendations/RecommendedStoresRow.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';
import 'package:zing/Widgets/Shared/zing_shimmer.dart';
import 'package:zing/Widgets/Shared/zing_store_card.dart';

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> {
  String? _selectedCategory;
  Position? _currentPosition;
  bool _initialized = false;

  final Map<String, double> _storeRatings = {};
  final ScrollController _scrollController = ScrollController();

  static const List<_CategoryItem> _categories = [
    _CategoryItem('Electronics', FontAwesomeIcons.laptop, Color(0xFF5856D6), Color(0xFF7D7AFF)),
    _CategoryItem('Clothing', FontAwesomeIcons.shirt, Color(0xFFFF2D55), Color(0xFFFF6482)),
    _CategoryItem('Food', FontAwesomeIcons.utensils, Color(0xFFFF9500), Color(0xFFFFB340)),
    _CategoryItem('Sports', FontAwesomeIcons.basketball, Color(0xFF34C759), Color(0xFF5ADB7B)),
    _CategoryItem('Beauty', FontAwesomeIcons.sprayCan, Color(0xFFAF52DE), Color(0xFFC77DFF)),
    _CategoryItem('Education', FontAwesomeIcons.graduationCap, Color(0xFF007AFF), Color(0xFF409CFF)),
    _CategoryItem('Electrical', FontAwesomeIcons.bolt, Color(0xFFFFCC00), Color(0xFFFFD60A)),
    _CategoryItem('Kids', FontAwesomeIcons.baby, Color(0xFF32ADE6), Color(0xFF64D2FF)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _initialized = true);
      RecentStores.load();
      final recProvider = Provider.of<RecommendationProvider>(context, listen: false);
      recProvider.logEvent(eventType: 'home-page-view');
      recProvider.fetchRecommendations(placement: RecommendationProvider.homeRecommended);
      // Give the first frame room before asking for location.
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) _checkAndGetLocation();
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ location

  Future<void> _checkAndGetLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        await _getCurrentLocation();
      }
    } catch (e) {
      debugPrint('Error checking location: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) setState(() => _currentPosition = last);

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 100),
      ).timeout(const Duration(seconds: 20), onTimeout: () {
        if (_currentPosition != null) return _currentPosition!;
        throw TimeoutException('Location request timed out');
      });
      if (mounted) setState(() => _currentPosition = position);
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  double? _distanceTo(Store store) {
    final here = _currentPosition;
    if (here == null) return null;
    return Geolocator.distanceBetween(
          here.latitude, here.longitude, store.location.latitude, store.location.longitude) /
        1000;
  }

  void _loadStoreRatings(List<Store> stores) {
    for (final store in stores) {
      final id = store.id;
      if (id == null || _storeRatings.containsKey(id)) continue;
      _storeRatings[id] = store.ratingAvg ?? 0; // placeholder until loaded
      store.getAverageRating().then((rating) {
        if (mounted) setState(() => _storeRatings[id] = rating);
      });
    }
  }

  String _greeting(CustomUser? user) {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final first = user?.name.trim().split(' ').first ?? '';
    return first.isEmpty ? part : '$part, $first';
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final storeProvider = Provider.of<StoreProvider>(context);
    final user = Provider.of<CustomUserProvider>(context).user;

    final filtered = storeProvider.activeStores
        .where((s) => _selectedCategory == null || s.category == _selectedCategory)
        .toList();
    _loadStoreRatings(filtered);

    final nearby = <Store>[];
    final others = <Store>[];
    for (final store in filtered) {
      final d = _distanceTo(store);
      (d != null && d <= 5 ? nearby : others).add(store);
    }
    nearby.sort((a, b) => _distanceTo(a)!.compareTo(_distanceTo(b)!));
    others.sort((a, b) =>
        (_distanceTo(a) ?? double.infinity).compareTo(_distanceTo(b) ?? double.infinity));

    final loading = !_initialized || storeProvider.isLoading;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          _buildNavBar(user),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              await storeProvider.fetchStores();
              _storeRatings.clear();
            },
          ),
          SliverToBoxAdapter(child: _buildGreeting(user)),
          SliverToBoxAdapter(
            child: ZingSearchField(
              placeholder: 'Stores, products, categories',
              readOnly: true,
              onTap: () => Navigator.of(context).push(zingRoute(const SearchExploreScreen(autofocus: true))),
            ),
          ),
          if (loading)
            SliverToBoxAdapter(child: _buildSkeleton())
          else ...[
            SliverToBoxAdapter(child: _buildOffers()),
            const SliverToBoxAdapter(child: ZingSectionTitle(title: 'Categories')),
            SliverToBoxAdapter(child: _buildCategories()),
            SliverToBoxAdapter(child: _buildRecentlyViewed(storeProvider.activeStores, user)),
            SliverToBoxAdapter(
              child: RecommendedStoresRow(
                placement: RecommendationProvider.homeRecommended,
                sectionTitle: 'Picked for You',
                user: user,
              ),
            ),
            if (nearby.isNotEmpty) ...[
              ZingSectionTitle(
                title: 'Near You',
                actionLabel: '${nearby.length} stores',
              ).asSliver(),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 214,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: nearby.length,
                    itemBuilder: (context, i) => ZingReveal(
                      axis: Axis.horizontal,
                      delay: Duration(milliseconds: 50 * (i % 4)),
                      child: ZingStoreCard(
                        store: nearby[i],
                        user: user,
                        distance: _distanceTo(nearby[i]),
                        rating: _storeRatings[nearby[i].id] ?? 0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: _buildAds()),
            if (others.isNotEmpty) ...[
              ZingSectionTitle(
                title: _selectedCategory ?? (nearby.isEmpty ? 'All Stores' : 'More to Explore'),
              ).asSliver(),
              SliverList.builder(
                itemCount: others.length,
                itemBuilder: (context, i) => ZingReveal(
                  child: ZingStoreCard(
                    wide: true,
                    store: others[i],
                    user: user,
                    distance: _distanceTo(others[i]),
                    rating: _storeRatings[others[i].id] ?? 0,
                  ),
                ),
              ),
            ],
            if (filtered.isEmpty) SliverToBoxAdapter(child: _buildNoStores()),
          ],
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 90)),
        ],
      ),
    );
  }

  Widget _buildNavBar(CustomUser? user) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return CupertinoSliverNavigationBar(
      largeTitle: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/zing.png', height: 28, color: cs.primary),
          const SizedBox(width: 8),
          const Text('ZING'),
        ],
      ),
      middle: const Text('ZING'),
      alwaysShowMiddle: false,
      automaticallyImplyLeading: false,
      backgroundColor: theme.scaffoldBackgroundColor.withValues(alpha: 0.82),
      border: null,
      stretch: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Consumer<NotificationProvider>(
            builder: (context, n, _) => ZingBarButton(
              icon: CupertinoIcons.bell,
              tooltip: 'Notifications',
              badge: ZingBadge(count: n.unreadCount),
              onPressed: () => Navigator.of(context).push(zingRoute(const NotificationsScreen())),
            ),
          ),
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: cs.primary.withValues(alpha: 0.14),
                backgroundImage: user.profileImageUrl.isNotEmpty
                    ? CachedNetworkImageProvider(user.profileImageUrl)
                    : null,
                child: user.profileImageUrl.isEmpty
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                        style: ZingType.style(14, weight: FontWeight.w700, color: cs.primary),
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGreeting(CustomUser? user) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(_greeting(user), style: ZingType.subhead(cs.onSurfaceVariant)),
          ),
          AnimatedSwitcher(
            duration: ZingMotion.medium,
            child: _currentPosition == null
                ? const SizedBox.shrink()
                : Row(
                    key: const ValueKey('loc'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(CupertinoIcons.location_fill, size: 13, color: cs.primary),
                      const SizedBox(width: 4),
                      Text('Near you', style: ZingType.footnote(cs.primary)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOffers() {
    final cs = Theme.of(context).colorScheme;
    return Consumer<OfferProvider>(
      builder: (context, offers, _) {
        if (offers.isLoading) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: ZingShimmer.box(height: 180, borderRadius: ZingRadius.xl),
          );
        }
        if (offers.offers.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ZingDepthCarousel(
            height: 184,
            itemCount: offers.offers.length,
            itemBuilder: (context, i) {
              final offer = offers.offers[i];
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ZingRadius.xl - 4),
                  boxShadow: ZingShadows.card,
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: offer.imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => ColoredBox(color: cs.surfaceContainerHighest),
                      errorWidget: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [ZingColors.primary, ZingColors.secondary],
                          ),
                        ),
                      ),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x00000000), Color(0x99000000)],
                          stops: [0.45, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 14,
                      child: ZingGlass(
                        borderRadius: BorderRadius.circular(100),
                        color: ZingColors.secondary,
                        opacity: 0.9,
                        blur: 8,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Text('OFFER',
                              style: ZingType.style(11,
                                  weight: FontWeight.w700, color: Colors.white, letterSpacing: 0.8)),
                        ),
                      ),
                    ),
                    if (offer.text.isNotEmpty)
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 14,
                        child: Text(
                          offer.text,
                          style: ZingType.title3(Colors.white),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCategories() {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 104,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _categories.length,
        itemBuilder: (context, i) {
          final c = _categories[i];
          final selected = _selectedCategory == c.name;
          final dimmed = _selectedCategory != null && !selected;
          return ZingReveal(
            axis: Axis.horizontal,
            offset: 18,
            delay: Duration(milliseconds: 40 * i),
            child: ZingPressable(
              pressedScale: 0.9,
              onTap: () => setState(() => _selectedCategory = selected ? null : c.name),
              child: AnimatedOpacity(
                duration: ZingMotion.medium,
                opacity: dimmed ? 0.45 : 1,
                child: SizedBox(
                  width: 78,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: ZingMotion.medium,
                        curve: ZingMotion.emphasized,
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [c.light, c.color],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: selected
                              ? Border.all(color: cs.surface, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: c.color.withValues(alpha: selected ? 0.55 : 0.28),
                              blurRadius: selected ? 16 : 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(child: FaIcon(c.icon, color: Colors.white, size: 24)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.name,
                        style: ZingType.style(12,
                            weight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? c.color : cs.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
  }

  /// Small round shortcuts back to the stores this device opened last.
  Widget _buildRecentlyViewed(List<Store> stores, CustomUser? user) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<List<String>>(
      valueListenable: RecentStores.ids,
      builder: (context, ids, _) {
        final recent = <Store>[
          for (final id in ids)
            for (final s in stores)
              if (s.id == id) s,
        ];
        if (recent.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ZingSectionTitle(
              title: 'Recently Viewed',
              actionLabel: 'Clear',
              onAction: RecentStores.clear,
            ),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: recent.length,
                itemBuilder: (context, i) {
                  final store = recent[i];
                  return ZingPressable(
                    pressedScale: 0.92,
                    onTap: () => openStore(context, store, user: user),
                    child: SizedBox(
                      width: 80,
                      child: Column(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.surface,
                              border: Border.all(color: cs.surface, width: 3),
                              boxShadow: ZingShadows.soft,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: store.imageUrl.isEmpty
                                ? Container(
                                    color: cs.primary.withValues(alpha: 0.12),
                                    alignment: Alignment.center,
                                    child: Text(
                                      store.name.isNotEmpty ? store.name[0].toUpperCase() : '?',
                                      style: ZingType.title3(cs.primary),
                                    ),
                                  )
                                : CachedNetworkImage(imageUrl: store.imageUrl, fit: BoxFit.cover),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            store.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: ZingType.style(12, weight: FontWeight.w500, color: cs.onSurface),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAds() {
    final cs = Theme.of(context).colorScheme;
    return Consumer<AdvertisementProvider>(
      builder: (context, ads, _) {
        if (ads.isLoading || ads.advertisements.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ZingSectionTitle(title: 'Featured'),
            ZingDepthCarousel(
              height: 140,
              viewportFraction: 0.9,
              autoPlay: const Duration(seconds: 7),
              itemCount: ads.advertisements.length,
              itemBuilder: (context, i) => Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ZingRadius.lg),
                  boxShadow: ZingShadows.soft,
                ),
                clipBehavior: Clip.antiAlias,
                child: CachedNetworkImage(
                  imageUrl: ads.advertisements[i].imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(color: cs.surfaceContainerHighest),
                  errorWidget: (_, __, ___) => ColoredBox(color: cs.surfaceContainerHighest),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoStores() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 0),
      child: Column(
        children: [
          Icon(CupertinoIcons.bag, size: 44, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(
            _selectedCategory == null ? 'No stores yet' : 'No $_selectedCategory stores yet',
            style: ZingType.headline(cs.onSurface),
          ),
          const SizedBox(height: 6),
          Text('Check back soon — new local stores join every week.',
              style: ZingType.subhead(cs.onSurfaceVariant), textAlign: TextAlign.center),
          if (_selectedCategory != null)
            CupertinoButton(
              onPressed: () => setState(() => _selectedCategory = null),
              child: Text('Show all categories', style: ZingType.body(cs.primary)),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZingShimmer.box(height: 180, borderRadius: ZingRadius.xl),
          const SizedBox(height: 30),
          ZingShimmer.box(width: 140, height: 22),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              4,
              (_) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ZingShimmer.box(width: 62, height: 62, borderRadius: 18),
              ),
            ),
          ),
          const SizedBox(height: 30),
          ZingShimmer.box(width: 160, height: 22),
          const SizedBox(height: 16),
          ZingShimmer.box(height: 220, borderRadius: ZingRadius.xl),
        ],
      ),
    );
  }
}

class _CategoryItem {
  final String name;
  final FaIconData icon;
  final Color color;
  final Color light;
  const _CategoryItem(this.name, this.icon, this.color, this.light);
}

extension on Widget {
  Widget asSliver() => SliverToBoxAdapter(child: this);
}
