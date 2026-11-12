import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/AdvertisementProvider.dart';
import 'package:zing/Service/OfferProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/NotificationProvider.dart';
import 'package:zing/Widgets/Shared/zing_store_card.dart';
import 'package:zing/Widgets/Shared/zing_section_header.dart';
import 'package:zing/Widgets/Shared/zing_shimmer.dart';
import 'package:zing/Widgets/Recommendations/RecommendedStoresRow.dart';
import 'package:zing/screen/NotificationsScreen.dart';

class HomePageScreen extends StatefulWidget {
  const HomePageScreen({super.key});

  @override
  State<HomePageScreen> createState() => _HomePageScreenState();
}

class _HomePageScreenState extends State<HomePageScreen> with TickerProviderStateMixin {
  AnimationController? _loadingAnimationController;
  AnimationController? _logoAnimationController;

  String? _selectedCategory;
  Position? _currentPosition;
  bool _isMounted = true;
  bool _isInitialized = false;

  Map<String, double> _storeRatings = {};

  final ScrollController _scrollController = ScrollController();

  final List<_CategoryItem> _categories = [
    _CategoryItem('Electronics', FontAwesomeIcons.laptop, const Color(0xFF5B7FFF), const Color(0xFFEBF0FF)),
    _CategoryItem('Clothing', FontAwesomeIcons.tshirt, const Color(0xFFFF6B6B), const Color(0xFFFFECEE)),
    _CategoryItem('Food', FontAwesomeIcons.utensils, const Color(0xFFFFAE33), const Color(0xFFFFF6E9)),
    _CategoryItem('Sports', FontAwesomeIcons.basketballBall, const Color(0xFF43B97F), const Color(0xFFE6F8EF)),
    _CategoryItem('Beauty', FontAwesomeIcons.sprayCan, const Color(0xFFD77FE3), const Color(0xFFF9EBFF)),
    _CategoryItem('Education', FontAwesomeIcons.graduationCap, const Color(0xFF6C63FF), const Color(0xFFEBEAFF)),
    _CategoryItem('Electrical', FontAwesomeIcons.bolt, const Color(0xFFFFA726), const Color(0xFFFFF3E0)),
    _CategoryItem('Kids', FontAwesomeIcons.baby, const Color(0xFF4DB6AC), const Color(0xFFE0F2F1)),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _isMounted) _initializeScreen();
      });
    });
  }

  void _initializeScreen() {
    if (!_isMounted || !mounted || _isInitialized) return;

    setState(() => _isInitialized = true);

    _loadingAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final recProvider = Provider.of<RecommendationProvider>(context, listen: false);
      recProvider.logEvent(eventType: 'home-page-view');
      recProvider.fetchRecommendations(placement: RecommendationProvider.homeRecommended);
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _isMounted) _checkAndGetLocation();
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    _loadingAnimationController?.dispose();
    _logoAnimationController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkAndGetLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return;

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        await _getCurrentLocation();
      }
    } catch (e) {
      debugPrint('Error checking location: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && _isMounted && mounted) {
        setState(() => _currentPosition = lastPosition);
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 100),
      ).timeout(const Duration(seconds: 20), onTimeout: () {
        if (_currentPosition != null) return _currentPosition!;
        throw TimeoutException('Location request timed out');
      });

      if (_isMounted && mounted) {
        setState(() => _currentPosition = position);
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  double? _calculateDistance(double storeLat, double storeLng) {
    if (_currentPosition == null) return null;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude, _currentPosition!.longitude, storeLat, storeLng,
    ) / 1000;
  }

  void _loadStoreRatings(List<Store> stores) {
    for (var store in stores) {
      if (!_storeRatings.containsKey(store.id)) {
        store.getAverageRating().then((rating) {
          if (_isMounted && mounted) {
            setState(() => _storeRatings[store.id!] = rating);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final storeProvider = Provider.of<StoreProvider>(context);
    final userProvider = Provider.of<CustomUserProvider>(context);
    final screenSize = MediaQuery.of(context).size;

    if (!_isInitialized) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: cs.primary),
        ),
      );
    }

    return Scaffold(
      body: FutureBuilder<CustomUser?>(
        future: userProvider.fetchUserDetails(),
        builder: (context, snapshot) {
          final user = snapshot.data;
          return NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [_buildAppBar(screenSize, user, theme)];
            },
            body: storeProvider.isLoading
                ? _buildShimmerLoading(screenSize, theme)
                : _buildHomeContent(storeProvider, user, screenSize, theme),
          );
        },
      ),
    );
  }

  // Clean white app bar with ZING logo left, notification bell right
  SliverAppBar _buildAppBar(Size screenSize, CustomUser? user, ThemeData theme) {
    final cs = theme.colorScheme;

    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      snap: false,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      backgroundColor: cs.surface,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(ZingSpacing.lg, ZingSpacing.sm, ZingSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo row
                Row(
                  children: [
                    Image.asset('assets/images/zing.png', height: 28, color: cs.primary),
                    const SizedBox(width: 8),
                    Text('ZING', style: theme.textTheme.headlineMedium?.copyWith(
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    )),
                    const Spacer(),
                    // Notification bell
                    Consumer<NotificationProvider>(
                      builder: (context, notifProvider, _) {
                        return IconButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          ),
                          icon: Badge(
                            isLabelVisible: notifProvider.unreadCount > 0,
                            label: Text('${notifProvider.unreadCount}'),
                            backgroundColor: cs.secondary,
                            child: Icon(Icons.notifications_outlined, color: cs.onSurface),
                          ),
                        );
                      },
                    ),
                    // Profile avatar
                    if (user != null)
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: cs.surfaceContainerHighest,
                        backgroundImage: user.profileImageUrl.isNotEmpty
                            ? NetworkImage(user.profileImageUrl)
                            : null,
                        child: user.profileImageUrl.isEmpty
                            ? Text(
                                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: cs.primary, fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Welcome text
                Text(
                  'Welcome${user?.name != null && user!.name.isNotEmpty ? ", ${user.name.split(' ')[0]}" : ""}',
                  style: theme.textTheme.headlineSmall,
                ),
              ],
            ),
          ),
        ),
        titlePadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildShimmerLoading(Size screenSize, ThemeData theme) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: ZingSpacing.md, bottom: ZingSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.lg),
                  child: ZingShimmer.box(height: screenSize.height * 0.2, borderRadius: 20),
                ),
                const SizedBox(height: ZingSpacing.xl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.lg),
                  child: ZingShimmer.box(width: screenSize.width * 0.4, height: 24),
                ),
                const SizedBox(height: ZingSpacing.md),
                SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 6,
                    itemBuilder: (_, __) => Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Column(
                        children: [
                          ZingShimmer.circle(size: 70),
                          const SizedBox(height: 8),
                          ZingShimmer.box(width: 60, height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeContent(StoreProvider storeProvider, CustomUser? user, Size screenSize, ThemeData theme) {
    final cs = theme.colorScheme;

    List<Store> filteredStores = storeProvider.stores.where((store) {
      return _selectedCategory == null || store.category == _selectedCategory;
    }).toList();

    _loadStoreRatings(filteredStores);

    List<Store> nearbyStores = [];
    List<Store> otherStores = [];

    for (var store in filteredStores) {
      final distance = _calculateDistance(store.location.latitude, store.location.longitude);
      if (distance != null && distance <= 5) {
        nearbyStores.add(store);
      } else {
        otherStores.add(store);
      }
    }

    otherStores.sort((a, b) {
      final dA = _calculateDistance(a.location.latitude, a.location.longitude) ?? double.infinity;
      final dB = _calculateDistance(b.location.latitude, b.location.longitude) ?? double.infinity;
      return dA.compareTo(dB);
    });

    return RefreshIndicator(
      onRefresh: () async {
        await storeProvider.fetchStores();
        return Future.delayed(const Duration(milliseconds: 300));
      },
      color: cs.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: ZingSpacing.md)),
          // Offer carousel
          SliverToBoxAdapter(child: _buildOfferCarousel(screenSize, theme)),
          // Categories
          SliverToBoxAdapter(
            child: ZingSectionHeader(
              title: 'Categories',
              actionText: _selectedCategory != null ? 'Clear' : null,
              onAction: () => setState(() => _selectedCategory = null),
            ),
          ),
          SliverToBoxAdapter(child: _buildCategorySelector(theme)),
          // Recommendations
          SliverToBoxAdapter(
            child: RecommendedStoresRow(
              placement: RecommendationProvider.homeRecommended,
              sectionTitle: 'Recommended for You',
              user: user,
            ),
          ),
          // Nearby stores
          if (nearbyStores.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: ZingSectionHeader(
                title: 'Nearby Stores',
                icon: Icons.location_on_rounded,
                iconColor: cs.primary,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 260,
                child: _buildStoresList(nearbyStores, user),
              ),
            ),
          ],
          // All stores
          if (otherStores.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: ZingSectionHeader(
                title: 'All Stores',
                icon: Icons.storefront_rounded,
                iconColor: cs.secondary,
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 260,
                child: _buildStoresList(otherStores, user),
              ),
            ),
          ],
          // Advertisements
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: ZingSpacing.xl, bottom: ZingSpacing.md),
              child: _buildAdvertisementSection(screenSize, theme),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildOfferCarousel(Size screenSize, ThemeData theme) {
    final cs = theme.colorScheme;

    return Consumer<OfferProvider>(
      builder: (context, offerProvider, _) {
        if (offerProvider.isLoading) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZingShimmer.box(width: 150, height: 24),
                const SizedBox(height: ZingSpacing.md),
                ZingShimmer.box(height: screenSize.height * 0.2, borderRadius: 20),
              ],
            ),
          );
        }

        if (offerProvider.offers.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZingSectionHeader(
                title: 'Special Offers',
                icon: Icons.local_offer_rounded,
                iconColor: cs.secondary,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: ZingSpacing.md),
              RepaintBoundary(
                child: CarouselSlider.builder(
                  itemCount: offerProvider.offers.length,
                  itemBuilder: (context, index, _) {
                    final offer = offerProvider.offers[index];
                    return Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: ZingShadows.soft,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(
                                offer.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(Icons.error_outline, color: cs.error, size: 32),
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                                    stops: const [0.6, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 16, left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: cs.secondary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'SPECIAL OFFER',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  options: CarouselOptions(
                    height: screenSize.height * 0.2,
                    viewportFraction: 1.0,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 5),
                    autoPlayAnimationDuration: const Duration(milliseconds: 800),
                    autoPlayCurve: Curves.fastOutSlowIn,
                    pauseAutoPlayOnTouch: true,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategorySelector(ThemeData theme) {
    final cs = theme.colorScheme;
    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category.name;

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _selectedCategory = isSelected ? null : category.name);
            },
            child: Container(
              width: 85,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: isSelected ? category.color : category.bgColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: isSelected
                          ? [BoxShadow(color: category.color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                          : null,
                    ),
                    child: Center(
                      child: FaIcon(category.icon, color: isSelected ? Colors.white : category.color, size: 26),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? category.color : cs.onSurface,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (isSelected)
                    Container(
                      width: 16, height: 2,
                      decoration: BoxDecoration(
                        color: category.color,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoresList(List<Store> stores, CustomUser? user) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        final distance = _calculateDistance(store.location.latitude, store.location.longitude);
        final rating = _storeRatings[store.id] ?? 0.0;

        return ZingStoreCard(
          store: store,
          user: user,
          distance: distance,
          rating: rating,
        );
      },
    );
  }

  Widget _buildAdvertisementSection(Size screenSize, ThemeData theme) {
    final cs = theme.colorScheme;

    return Consumer<AdvertisementProvider>(
      builder: (context, adProvider, _) {
        if (adProvider.isLoading) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZingShimmer.box(width: 150, height: 24),
                const SizedBox(height: ZingSpacing.md),
                ZingShimmer.box(height: screenSize.height * 0.15, borderRadius: 20),
              ],
            ),
          );
        }

        if (adProvider.advertisements.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZingSectionHeader(
                title: 'Featured Ads',
                icon: Icons.campaign_rounded,
                iconColor: cs.tertiary,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: ZingSpacing.md),
              RepaintBoundary(
                child: CarouselSlider.builder(
                  itemCount: adProvider.advertisements.length,
                  options: CarouselOptions(
                    height: screenSize.height * 0.15,
                    viewportFraction: 1.0,
                    autoPlay: true,
                    autoPlayInterval: const Duration(seconds: 7),
                    autoPlayAnimationDuration: const Duration(milliseconds: 800),
                    enableInfiniteScroll: true,
                  ),
                  itemBuilder: (context, index, _) {
                    final ad = adProvider.advertisements[index];
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: ZingShadows.soft,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.network(
                          ad.imageUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(Icons.error_outline, color: cs.error, size: 32),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CategoryItem {
  final String name;
  final IconData icon;
  final Color color;
  final Color bgColor;
  const _CategoryItem(this.name, this.icon, this.color, this.bgColor);
}
