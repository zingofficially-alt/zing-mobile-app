import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'package:zing/Chat/ChatScreen.dart';
import 'package:zing/Modal/CoustomUser.dart'; // Make sure this import matches your project structure
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/screen/StoreScreen/ProductDetailsScreen.dart';
import 'package:zing/Widgets/Recommendations/RecommendedProductsRow.dart';

import 'package:zing/screen/StoreScreen/customCarousel.dart';
import 'package:zing/Service/RecentStores.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';
import 'package:zing/Cart/CartProvider.dart';
import 'package:zing/config/env.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;
  final CustomUser? user; // Made optional to allow browsing without login

  const StoreDetailScreen({
    super.key,
    required this.store,
    this.user, // No longer required
  });

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> with SingleTickerProviderStateMixin {
  // Controllers
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  GoogleMapController? _mapController;

  // State variables
  Position? _userPosition;
  List<LatLng> polylineCoordinates = [];
  Set<Polyline> polylines = {};
  double _currentRating = 0;
  bool _hasRated = false;
  double _averageRating = 0;
  bool _isScrolled = false;
  int _selectedProductCategoryIndex = 0;
  List<String>? _productCategories;
  bool _isFavorite = false;
  String _productQuery = '';
  // 0 = store order, 1 = price low to high, 2 = price high to low
  int _productSort = 0;
  static const _productSortLabels = ['Featured', 'Price: Low to High', 'Price: High to Low'];
  YoutubePlayerController? _youtubeController;
  bool _showingVideo = false;

  @override
  void initState() {
    super.initState();
    RecentStores.add(widget.store.id);
    _getUserLocation();
    _checkIfUserHasRated();
    _loadAverageRating();
    _checkFavoriteStatus();
    _initializeProductCategories();

    // Log store detail-page-view + fetch product recommendations
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final recProvider =
          Provider.of<RecommendationProvider>(context, listen: false);
      final productIds = widget.store.products
          .map((p) => 'product_${widget.store.id}_${p.id}')
          .toList();

      recProvider.logEvent(
        eventType: 'detail-page-view',
        productIds: ['store_${widget.store.id}'],
      );
      recProvider.fetchRecommendations(
        placement: RecommendationProvider.storeAlsoViewed,
        productIds: productIds,
      );
    });

    // Initialize tab controller
    _tabController = TabController(
      length: _productCategories?.length ?? 1,
      vsync: this,
    );

    // Set up scroll listener
    _scrollController.addListener(_onScroll);

    // Set system UI style — no context available here, use neutral colors
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: ZingColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  void _initializeProductCategories() {
    Set<String> categories = {'All'};

    // Extract unique categories from products
    for (var product in widget.store.products) {
      if (product.description != null && product.description!.isNotEmpty) {
        categories.add(product.description!);
      }
    }

    setState(() {
      _productCategories = categories.toList();
    });
  }

  void _onScroll() {
    final isScrolled = _scrollController.offset > _heroHeight - 110;
    if (isScrolled != _isScrolled) {
      // Use post-frame callback to prevent semantics assertion errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isScrolled = isScrolled;
          });
        }
      });
    }
  }

  void _checkFavoriteStatus() {
    // Only check favorites if user is logged in
    if (widget.user != null && widget.user!.favorites != null && widget.user!.favorites!.contains(widget.store.id)) {
      setState(() {
        _isFavorite = true;
      });
    }
  }

  /// Adds one unit of [product] to the cart, respecting available stock.
  Future<void> _quickAddToCart(Product product) async {
    HapticFeedback.mediumImpact();
    if (widget.user == null) {
      await _showLoginDialog();
      return;
    }
    if (!mounted) return;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    final cart = Provider.of<CartProvider>(context, listen: false);

    final alreadyInCart = cart.items
        .where((i) => i.id == product.id)
        .fold<int>(0, (total, i) => total + i.quantity);
    if (!product.inStock || alreadyInCart >= product.quantity) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(product.inStock
            ? 'Only ${product.quantity} of ${product.name} in stock'
            : '${product.name} is out of stock'),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final price = product.discount != null && product.discount! > 0
        ? product.price * (1 - product.discount! / 100)
        : product.price;

    await cart.addItem(
      CartItem(
        id: product.id,
        name: product.name,
        price: price,
        imageUrl: product.imageUrl,
        storeId: widget.store.id,
        quantity: 1,
      ),
      context,
    );
    if (!mounted) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${product.name} added to cart',
          style: theme.textTheme.bodyMedium?.copyWith(color: cs.onPrimary),
        ),
        backgroundColor: ZingColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _toggleFavorite() async {
    // Require login for favorites
    if (widget.user == null) {
      await _showLoginDialog();
      return;
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    setState(() {
      _isFavorite = !_isFavorite;
    });

    // Update the user's favorites
    if (_isFavorite) {
      widget.user!.addFavorite(widget.store.id!);
    } else {
      widget.user!.removeFavorite(widget.store.id!);
    }

    final favorites = Supabase.instance.client.from('user_favorites');
    (_isFavorite
            ? favorites.upsert({'user_id': widget.user!.id, 'store_id': widget.store.id})
            : favorites
                .delete()
                .eq('user_id', widget.user!.id)
                .eq('store_id', widget.store.id!))
        .then((_) {
      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isFavorite
                ? 'Added to favorites'
                : 'Removed from favorites',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onPrimary),
          ),
          backgroundColor: ZingColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }).catchError((error) {
      // Revert state change on error
      if (!mounted) return;
      setState(() {
        _isFavorite = !_isFavorite;
      });

      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Error updating favorites'),
          backgroundColor: cs.error,
        ),
      );
    });
  }

  // Show login dialog when user tries to perform account-based actions
  Future<bool> _showLoginDialog() async {

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.login_rounded,
                color: cs.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Login Required',
                style: theme.textTheme.headlineSmall,
              ),
            ],
          ),
          content: Text(
            'You need to be logged in to perform this action. Would you like to login now?',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, true);
                // Navigate to login screen
                Navigator.pushNamed(context, '/login');
              },
              child: Text(
                'Login',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _mapController?.dispose();
    _youtubeController?.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Location & Directions
  Future<void> _getUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _userPosition = position;
        _getDirections();
      });
    } catch (e) {
      debugPrint("Error getting user location: $e");
    }
  }

  Future<void> _getDirections() async {
    if (_userPosition == null) return;

    String baseUrl = 'https://maps.googleapis.com/maps/api/directions/json?';
    String origin = '${_userPosition!.latitude},${_userPosition!.longitude}';
    String destination =
        '${widget.store.location.latitude},${widget.store.location.longitude}';
    const String apiKey = Env.googleDirectionsApiKey; // From .env
    if (apiKey.isEmpty) {
      debugPrint('GOOGLE_DIRECTIONS_API_KEY not set in .env; skipping directions.');
      return;
    }

    final url = '$baseUrl'
        'origin=$origin&destination=$destination&key=$apiKey';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      if ((data['routes'] as List).isNotEmpty) {
        var points = data['routes'][0]['overview_polyline']['points'];
        _decodePolyline(points);
        _updateCameraPosition();
      }
    } else {
      debugPrint('Error fetching directions');
    }
  }

  void _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(
        (lat / 1E5).toDouble(),
        (lng / 1E5).toDouble(),
      ));
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    setState(() {
      polylineCoordinates = points;
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: polylineCoordinates,
          color: cs.primary,
          width: 5,
        ),
      );
    });
  }

  void _updateCameraPosition() {
    if (_userPosition != null && _mapController != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _userPosition!.latitude < widget.store.location.latitude
              ? _userPosition!.latitude
              : widget.store.location.latitude,
          _userPosition!.longitude < widget.store.location.longitude
              ? _userPosition!.longitude
              : widget.store.location.longitude,
        ),
        northeast: LatLng(
          _userPosition!.latitude > widget.store.location.latitude
              ? _userPosition!.latitude
              : widget.store.location.latitude,
          _userPosition!.longitude > widget.store.location.longitude
              ? _userPosition!.longitude
              : widget.store.location.longitude,
        ),
      );

      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  // --------------------------------------------------------------------------
  // Ratings
  Future<void> _checkIfUserHasRated() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser != null) {
      bool hasRated = await widget.store.userHasRated(authUser.id);
      setState(() {
        _hasRated = hasRated;
      });
    }
  }

  Future<void> _loadAverageRating() async {
    double averageRating = await widget.store.getAverageRating();
    setState(() {
      _averageRating = averageRating;
    });
  }

  void _submitRating() async {
    // Require login for rating
    if (widget.user == null) {
      await _showLoginDialog();
      return;
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser != null) {
      await widget.store.submitRating(authUser.id, _currentRating);
      setState(() {
        _hasRated = true;
      });
      _loadAverageRating();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thank you for rating ${widget.store.name}!',
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onPrimary),
          ),
          backgroundColor: ZingColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _showRatingDialog() async {
    HapticFeedback.mediumImpact();

    // Require login for rating
    if (widget.user == null) {
      await _showLoginDialog();
      return;
    }
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return FadeIn(
          duration: const Duration(milliseconds: 200),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Text(
                    'Rate this store',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'How would you rate your experience at ${widget.store.name}?',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Rating stars
                  RatingBar.builder(
                    initialRating: 0,
                    minRating: 1,
                    direction: Axis.horizontal,
                    allowHalfRating: true,
                    itemCount: 5,
                    itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                    itemBuilder: (context, _) => const Icon(
                      Icons.star_rounded,
                      color: ZingColors.warning,
                    ),
                    onRatingUpdate: (rating) {
                      setState(() => _currentRating = rating);
                      HapticFeedback.selectionClick();
                    },
                  ),
                  const SizedBox(height: 30),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: cs.primary,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _submitRating();
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Submit',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // YouTube video handling
  void _showYouTubeVideo(String url) {
    // Extract YouTube video ID
    String? videoId = YoutubePlayer.convertUrlToId(url);

    if (videoId != null) {

      setState(() {
        _showingVideo = true;
        _youtubeController = YoutubePlayerController(
          initialVideoId: videoId,
          flags: const YoutubePlayerFlags(
            autoPlay: true,
            mute: false,
          ),
        );
      });

      // Show in fullscreen dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          final theme = Theme.of(context);
          final cs = theme.colorScheme;
          return AlertDialog(
            contentPadding: EdgeInsets.zero,
            backgroundColor: Colors.black,
            content: YoutubePlayer(
              controller: _youtubeController!,
              showVideoProgressIndicator: true,
              progressIndicatorColor: cs.primary,
              progressColors: ProgressBarColors(
                playedColor: cs.primary,
                handleColor: ZingColors.success,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _showingVideo = false;
                    _youtubeController?.dispose();
                    _youtubeController = null;
                  });
                },
                child: Text(
                  'Close',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  // Filter products by selected category
  List<Product> _getFilteredProducts() {
    Iterable<Product> products = widget.store.products;
    if (_productCategories != null && _selectedProductCategoryIndex != 0) {
      final selectedCategory = _productCategories![_selectedProductCategoryIndex];
      products = products.where((p) => p.description == selectedCategory);
    }
    if (_productQuery.isNotEmpty) {
      products = products.where((p) =>
          p.name.toLowerCase().contains(_productQuery) ||
          (p.description ?? '').toLowerCase().contains(_productQuery));
    }
    final list = products.toList();
    if (_productSort == 1) {
      list.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    } else if (_productSort == 2) {
      list.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    }
    return list;
  }

  void _pickProductSort() {
    showZingActionSheet(
      context,
      title: 'Sort products',
      actions: [
        for (var i = 0; i < _productSortLabels.length; i++)
          ZingSheetAction(
            label: _productSortLabels[i],
            isDefault: i == _productSort,
            onPressed: () => setState(() => _productSort = i),
          ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // BUILD THE UI
  static const double _heroHeight = 340;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: !_isScrolled || dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildHeroBar(),
            SliverToBoxAdapter(child: _buildStoreHeader()),
            SliverToBoxAdapter(child: _buildQuickActions()),
            SliverToBoxAdapter(child: _buildMediaCarouselSection()),
            SliverToBoxAdapter(child: _buildStoreDetails()),
            SliverToBoxAdapter(child: _buildLocationSection()),
            SliverToBoxAdapter(child: _buildProductsHeader()),
            _buildProductGrid(_getFilteredProducts()),
            SliverToBoxAdapter(
              child: RecommendedProductsRow(
                placement: RecommendationProvider.storeAlsoViewed,
                sectionTitle: 'You May Also Like',
                fallbackProducts: widget.store.products,
              ),
            ),
            SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 110)),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: _buildChatFAB(),
      ),
    );
  }

  /// Stretchy cover photo that zooms on pull-down, drifts with parallax on
  /// scroll, and gives way to a frosted bar with the store name.
  Widget _buildHeroBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    const toolbar = 48.0;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: _heroHeight,
      toolbarHeight: toolbar,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: !_isScrolled || theme.brightness == Brightness.dark
          ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
          : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
      leadingWidth: 60,
      leading: Center(
        child: _HeroBarButton(
          icon: CupertinoIcons.chevron_back,
          solid: _isScrolled,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      centerTitle: true,
      title: AnimatedOpacity(
        opacity: _isScrolled ? 1 : 0,
        duration: ZingMotion.fast,
        child: Text(widget.store.name, style: ZingType.headline(cs.onSurface)),
      ),
      actions: [
        _HeroBarButton(
          icon: _isFavorite ? CupertinoIcons.heart_fill : CupertinoIcons.heart,
          color: _isFavorite ? ZingColors.secondary : null,
          solid: _isScrolled,
          onTap: () {
            HapticFeedback.mediumImpact();
            _toggleFavorite();
          },
        ),
        const SizedBox(width: 8),
        _HeroBarButton(
          icon: CupertinoIcons.share,
          solid: _isScrolled,
          onTap: _shareStore,
        ),
        const SizedBox(width: 12),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final minH = toolbar + topInset;
          final maxH = _heroHeight + topInset;
          final expanded = ((constraints.maxHeight - minH) / (maxH - minH)).clamp(0.0, 1.0);
          final glass = ((0.28 - expanded) / 0.28).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    widget.store.imageUrl.isEmpty
                        ? _heroPlaceholder(cs)
                        : CachedNetworkImage(
                            imageUrl: widget.store.imageUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: ZingMotion.medium,
                            placeholder: (_, __) => ColoredBox(color: cs.surfaceContainerHighest),
                            errorWidget: (_, __, ___) => _heroPlaceholder(cs),
                          ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x66000000), Color(0x00000000), Color(0x00000000), Color(0x26000000)],
                          stops: [0, 0.3, 0.7, 1],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (glass > 0)
                IgnorePointer(
                  child: Opacity(
                    opacity: glass,
                    child: ZingGlass(
                      color: theme.scaffoldBackgroundColor,
                      opacity: 0.82,
                      border: Border(
                        bottom: BorderSide(color: cs.outline.withValues(alpha: 0.5), width: 0.5),
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _heroPlaceholder(ColorScheme cs) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ZingColors.primaryLight, ZingColors.primary, ZingColors.secondary],
          ),
        ),
        child: Icon(CupertinoIcons.bag, color: Colors.white.withValues(alpha: 0.6), size: 64),
      );

  // Name, category, status and rating under the cover photo.
  Widget _buildStoreHeader() {
    final cs = Theme.of(context).colorScheme;
    final store = widget.store;
    final status = store.openStatus();
    final ratingCount = store.ratingCount ?? store.ratings.length;

    return ZingReveal(
      offset: 16,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              store.category.toUpperCase(),
              style: ZingType.style(13, weight: FontWeight.w600, color: cs.primary, letterSpacing: 0.6),
            ),
            const SizedBox(height: 4),
            Text(store.name, style: ZingType.title1(cs.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (status != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: status.isOpen ? ZingColors.success : ZingColors.error,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status.label,
                        style: ZingType.subhead(status.isOpen ? ZingColors.success : ZingColors.error)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                GestureDetector(
                  onTap: _showRatingDialog,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.star_fill, size: 15, color: ZingColors.warning),
                      const SizedBox(width: 4),
                      Text(
                        _averageRating > 0 ? _averageRating.toStringAsFixed(1) : 'New',
                        style: ZingType.subhead(cs.onSurface).copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (ratingCount > 0)
                        Text(' ($ratingCount)', style: ZingType.subhead(cs.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            if (store.description.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(store.description, style: ZingType.subhead(cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  // Call / Directions / Rate / Share, in the Apple Maps place-card style.
  Widget _buildQuickActions() {
    return ZingReveal(
      delay: const Duration(milliseconds: 60),
      offset: 16,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: _buildQuickActionButton(
                icon: CupertinoIcons.phone_fill,
                label: 'Call',
                onTap: () => _launchPhone(widget.store.phoneNumber),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickActionButton(
                icon: CupertinoIcons.arrow_turn_up_right,
                label: 'Directions',
                onTap: _showDirectionsOptions,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickActionButton(
                icon: CupertinoIcons.star_fill,
                label: 'Rate',
                onTap: _showRatingDialog,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildQuickActionButton(
                icon: CupertinoIcons.share,
                label: 'Share',
                onTap: _shareStore,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Remove any spaces, dashes, or special characters from phone number
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanedNumber);

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        // If can't launch phone dialer, show error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unable to make phone call'),
              backgroundColor: cs.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _shareStore() async {
    HapticFeedback.mediumImpact();
    final store = widget.store;
    final String shareMessage = '''
Check out ${store.name} on Zing!

${store.category} store
${store.description}

Download Zing app to explore more stores near you!
https://play.google.com/store/apps/details?id=com.zing.app
''';

    try {
      await Share.share(
        shareMessage,
        subject: 'Check out ${store.name} on Zing!',
      );
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not share store'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return ZingPressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: Container(
        height: 62,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZingRadius.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: cs.primary, size: 21),
            const SizedBox(height: 5),
            Text(label, style: ZingType.style(12, weight: FontWeight.w600, color: cs.primary)),
          ],
        ),
      ),
    );
  }

  // Contact details, opening hours and delivery options as grouped lists.
  Widget _buildStoreDetails() {
    final store = widget.store;
    final hours = store.openingHours;
    final status = store.openStatus();
    final options = store.deliveryOptions ?? const <String>[];
    final today = DateTime.now().weekday - 1;

    return ZingReveal(
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Column(
          children: [
            ZingGroupedSection(
              header: 'Information',
              children: [
                if (store.phoneNumber.isNotEmpty)
                  ZingListRow(
                    icon: CupertinoIcons.phone_fill,
                    iconColor: ZingColors.success,
                    title: 'Phone',
                    value: store.phoneNumber,
                    showChevron: false,
                    onTap: () => _launchPhone(store.phoneNumber),
                  ),
                if (store.owner.name.isNotEmpty)
                  ZingListRow(
                    icon: CupertinoIcons.person_fill,
                    iconColor: ZingColors.accent,
                    title: 'Owner',
                    value: store.owner.name,
                  ),
                if (store.owner.email.isNotEmpty)
                  ZingListRow(
                    icon: CupertinoIcons.envelope_fill,
                    iconColor: ZingColors.primary,
                    title: 'Email',
                    subtitle: store.owner.email,
                    onTap: () => launchUrl(Uri(scheme: 'mailto', path: store.owner.email)),
                  ),
              ],
            ),
            if (hours != null)
              ZingGroupedSection(
                header: 'Opening Hours',
                footer: status?.label,
                separatorIndent: 16,
                children: [
                  for (var i = 0; i < 7; i++) _buildHoursRow(i, hours.days[i], i == today),
                ],
              ),
            if (options.isNotEmpty)
              ZingGroupedSection(
                header: 'Delivery',
                children: [
                  for (final option in options)
                    ZingListRow(
                      icon: option == 'Home Delivery'
                          ? CupertinoIcons.car_detailed
                          : CupertinoIcons.bag_fill,
                      iconColor: option == 'Home Delivery' ? ZingColors.success : ZingColors.warning,
                      title: option,
                      value: option == 'Home Delivery' && store.deliveryCost != null
                          ? 'Rs ${store.deliveryCost!.toStringAsFixed(0)}'
                          : (option == 'Home Delivery' ? null : 'Free'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursRow(int index, DayHours day, bool isToday) {
    final cs = Theme.of(context).colorScheme;
    final value = day.closed
        ? 'Closed'
        : day.isAllDay
            ? 'Open 24 hours'
            : '${DayHours.label(day.open)} – ${DayHours.label(day.close)}';
    final weight = isToday ? FontWeight.w600 : FontWeight.w400;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              OpeningHours.dayNames[index],
              style: ZingType.body(cs.onSurface).copyWith(fontWeight: weight),
            ),
          ),
          Text(
            value,
            style: ZingType.body(day.closed ? ZingColors.error : cs.onSurfaceVariant)
                .copyWith(fontWeight: weight),
          ),
        ],
      ),
    );
  }

  // Location and map section
  Widget _buildLocationSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FadeInUp(
      from: 20,
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 300),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Location'),
            const SizedBox(height: 16),

            GestureDetector(
              onTap: _openFullScreenMap,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: LatLng(
                            widget.store.location.latitude,
                            widget.store.location.longitude,
                          ),
                          zoom: 14,
                        ),
                        polylines: polylines,
                        markers: {
                          Marker(
                            markerId: MarkerId(widget.store.id!),
                            position: LatLng(
                              widget.store.location.latitude,
                              widget.store.location.longitude,
                            ),
                            infoWindow: InfoWindow(title: widget.store.name),
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                          ),
                          if (_userPosition != null)
                            Marker(
                              markerId: const MarkerId("user"),
                              position: LatLng(
                                _userPosition!.latitude,
                                _userPosition!.longitude,
                              ),
                              infoWindow: const InfoWindow(title: 'Your Location'),
                            ),
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                      ),

                      // View fullscreen button overlay
                      Positioned(
                        bottom: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fullscreen_rounded,
                                color: cs.onPrimary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'View fullscreen',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Distance info
            if (_userPosition != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: ZingColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ZingColors.success.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.directions_car_rounded,
                      color: ZingColors.success,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distance from your location',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _calculateDistance() ?? 'Calculating...',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openMapsApp,
                      icon: Icon(
                        Icons.navigation_rounded,
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

  // Opens the map in a full screen view
  // Show dialog to choose between in-app map or external navigation
  void _showDirectionsOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        return FadeIn(
          duration: const Duration(milliseconds: 200),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.map_rounded,
                    color: cs.primary,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Get Directions',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you\'d like to view directions',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  // View in-app map button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openFullScreenMap();
                      },
                      icon: const Icon(Icons.map_outlined),
                      label: Text(
                        'View Map in App',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onPrimary,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Navigate with external app button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _openMapsApp();
                      },
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text(
                        'Start Navigation',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.primary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: cs.primary, width: 2),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Cancel button
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openFullScreenMap() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenMap(
          polylines: polylines,
          storeLocation: LatLng(
            widget.store.location.latitude,
            widget.store.location.longitude,
          ),
          userPosition: _userPosition,
          storeName: widget.store.name,
        ),
      ),
    );
  }

  // Opens the maps app for navigation
  Future<void> _openMapsApp() async {
    HapticFeedback.mediumImpact();

    final double latitude = widget.store.location.latitude;
    final double longitude = widget.store.location.longitude;
    final String storeName = Uri.encodeComponent(widget.store.name);

    // Try to determine platform and open appropriate maps app
    try {
      // Google Maps URL (works on both iOS and Android)
      final Uri googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude&destination_place_id=$storeName'
      );

      // Apple Maps URL (works on iOS)
      final Uri appleMapsUrl = Uri.parse(
        'https://maps.apple.com/?daddr=$latitude,$longitude&q=$storeName'
      );

      // Try Google Maps app first (comgooglemaps://)
      final Uri googleMapsAppUrl = Uri.parse(
        'comgooglemaps://?daddr=$latitude,$longitude&directionsmode=driving'
      );

      // Try Apple Maps app (maps://)
      final Uri appleMapsAppUrl = Uri.parse(
        'maps://?daddr=$latitude,$longitude&q=$storeName'
      );

      bool launched = false;

      // Try to launch native Google Maps app on Android/iOS
      if (await canLaunchUrl(googleMapsAppUrl)) {
        launched = await launchUrl(googleMapsAppUrl, mode: LaunchMode.externalApplication);
      }

      // If Google Maps app didn't work, try Apple Maps app (iOS)
      if (!launched && await canLaunchUrl(appleMapsAppUrl)) {
        launched = await launchUrl(appleMapsAppUrl, mode: LaunchMode.externalApplication);
      }

      // If no native app worked, try web Google Maps
      if (!launched && await canLaunchUrl(googleMapsUrl)) {
        launched = await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
      }

      // If Google Maps web didn't work, try Apple Maps web
      if (!launched && await canLaunchUrl(appleMapsUrl)) {
        launched = await launchUrl(appleMapsUrl, mode: LaunchMode.externalApplication);
      }

      // If nothing worked, show error
      if (!launched && mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Unable to open maps application'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening maps: ${e.toString()}'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Calculate distance between user and store
  String? _calculateDistance() {
    if (_userPosition == null) return null;

    final distance = Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      widget.store.location.latitude,
      widget.store.location.longitude,
    );

    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} meters';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  // Products section header
  Widget _buildProductsHeader() {
    final categories = _productCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZingSectionTitle(
          title: 'Products',
          actionLabel: widget.store.products.length > 1
              ? (_productSort == 0 ? 'Sort' : _productSortLabels[_productSort].replaceFirst('Price: ', ''))
              : null,
          onAction: _pickProductSort,
        ),
        // Searching is only worth the space once there is a real catalogue.
        if (widget.store.products.length > 4)
          ZingSearchField(
            placeholder: 'Search in ${widget.store.name}',
            onChanged: (v) => setState(() => _productQuery = v.toLowerCase().trim()),
          ),
        if (categories != null && categories.length > 1)
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => ZingPill(
                label: categories[index],
                selected: _selectedProductCategoryIndex == index,
                onTap: () => setState(() => _selectedProductCategoryIndex = index),
              ),
            ),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  // Product grid
  Widget _buildProductGrid(List<Product> products) {
    final cs = Theme.of(context).colorScheme;

    if (products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
          child: Column(
            children: [
              Icon(CupertinoIcons.cube_box, size: 44, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(_productQuery.isEmpty ? 'No products here yet' : 'No matching products',
                  style: ZingType.headline(cs.onSurface)),
              const SizedBox(height: 4),
              Text(
                  _productQuery.isEmpty
                      ? 'This store hasn’t added products in this category.'
                      : 'Try a different word or clear the search.',
                  style: ZingType.subhead(cs.onSurfaceVariant), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.66,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ZingReveal(
            delay: Duration(milliseconds: 60 * (index % 2)),
            child: _buildProductCard(products[index]),
          ),
          childCount: products.length,
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    final cs = Theme.of(context).colorScheme;
    final hasDiscount = product.discount != null && product.discount! > 0;

    return ZingPressable(
      onTap: () => _openProductDetail(product),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(ZingRadius.lg),
          boxShadow: ZingShadows.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'product-${product.id}',
                    child: (product.imageUrl ?? '').isEmpty
                        ? Container(
                            color: cs.surfaceContainerHighest,
                            child: Icon(CupertinoIcons.photo, color: cs.onSurfaceVariant),
                          )
                        : CachedNetworkImage(
                            imageUrl: product.imageUrl!,
                            fit: BoxFit.cover,
                            fadeInDuration: ZingMotion.medium,
                            placeholder: (_, __) => ColoredBox(color: cs.surfaceContainerHighest),
                            errorWidget: (_, __, ___) => Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(CupertinoIcons.photo, color: cs.onSurfaceVariant),
                            ),
                          ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: ZingColors.secondary,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '−${product.discount!.toStringAsFixed(0)}%',
                          style: ZingType.style(12, weight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                  if (product.inStock)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: ZingPressable(
                        pressedScale: 0.85,
                        onTap: () => _quickAddToCart(product),
                        child: ZingGlass(
                          borderRadius: BorderRadius.circular(100),
                          color: Colors.white,
                          opacity: 0.9,
                          blur: 12,
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: Icon(CupertinoIcons.plus, color: cs.primary, size: 20),
                          ),
                        ),
                      ),
                    )
                  else
                    Positioned.fill(
                      child: ZingGlass(
                        color: Colors.black,
                        opacity: 0.35,
                        blur: 4,
                        child: Center(
                          child: Text('Sold Out',
                              style: ZingType.style(15, weight: FontWeight.w700, color: Colors.white)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 38,
                    child: Text(
                      product.name,
                      style: ZingType.style(15, weight: FontWeight.w600, color: cs.onSurface, height: 1.25),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Rs ${product.effectivePrice.toStringAsFixed(0)}',
                        style: ZingType.style(16, weight: FontWeight.w700, color: cs.onSurface),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Rs ${product.price.toStringAsFixed(0)}',
                            overflow: TextOverflow.ellipsis,
                            style: ZingType.footnote(cs.onSurfaceVariant)
                                .copyWith(decoration: TextDecoration.lineThrough),
                          ),
                        ),
                      ],
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

  void _openProductDetail(Product product) {
    Navigator.of(context).push(zingRoute(ProductDetailScreen(product: product, store: widget.store)));
  }

  // Floating "Message" button.
  Widget _buildChatFAB() {
    final cs = Theme.of(context).colorScheme;
    return ZingPressable(
      onTap: _chatWithStore,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(color: cs.primary.withValues(alpha: 0.38), blurRadius: 20, offset: const Offset(0, 8)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.chat_bubble_2_fill, color: Colors.white, size: 21),
            const SizedBox(width: 8),
            Text('Message Store', style: ZingType.style(16, weight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Floating action: chat with store
  Future<void> _chatWithStore() async {
    HapticFeedback.mediumImpact();

    // Require login for chat
    if (widget.user == null) {
      await _showLoginDialog();
      return;
    }

    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    String? fetchedChatId =
    await storeProvider.findChatId(widget.user!.id, widget.store.id!);

    if (fetchedChatId == null) {
      // No existing chat => create new
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            userId: widget.user!.id,
            storeName: widget.store.name,
            storeId: widget.store.id!,
            storeImageUrl: widget.store.imageUrl,
          ),
        ),
      );
    } else {
      // Existing chat => open
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            chatId: fetchedChatId,
            userId: widget.user!.id,
            storeName: widget.store.name,
            storeId: widget.store.id!,
            storeImageUrl: widget.store.imageUrl,
          ),
        ),
      );
    }
  }
  Widget _buildMediaCarouselSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // The cover photo is already the header; only show the gallery when the
    // store has videos to add to it.
    final hasVideos = (widget.store.videos ?? const []).isNotEmpty;
    if (!hasVideos) return const SizedBox.shrink();

    return FadeInUp(
      from: 20,
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSectionTitle('Videos & Photos'),
            ),
            const SizedBox(height: 8),

            // Use the enhanced carousel here
            EnhancedCarousel(
              store: widget.store,
              height: 250,
              autoPlay: true,
              showControls: true,
              indicatorActiveColor: cs.primary,
              indicatorInactiveColor: cs.onSurfaceVariant,
              fullScreenOnTap: true,
              onPageChanged: (index) {
                // You can handle page changes here if needed
                HapticFeedback.selectionClick();
              },
              // Custom loading widget (optional)
              loadingWidget: SizedBox(
                height: 250,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Spin(
                        infinite: true,
                        child: CircularProgressIndicator(
                          color: cs.primary,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Loading media...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  // --------------------------------------------------------------------------
  // Helper UI methods
  Widget _buildSectionTitle(String title) {
    final cs = Theme.of(context).colorScheme;
    return Text(title, style: ZingType.title2(cs.onSurface));
  }

  Widget _buildInfoCard({
    required String title,
    required Widget content,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZingRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: ZingType.headline(cs.onSurface)),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          color: cs.primary,
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --------------------------------------------------------------------------
// Enhanced Full Screen Map
class FullScreenMap extends StatefulWidget {
  final Set<Polyline> polylines;
  final LatLng storeLocation;
  final Position? userPosition;
  final String storeName;

  const FullScreenMap({
    super.key,
    required this.polylines,
    required this.storeLocation,
    this.userPosition,
    required this.storeName,
  });

  @override
  State<FullScreenMap> createState() => _FullScreenMapState();
}

class _FullScreenMapState extends State<FullScreenMap> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Directions to ${widget.storeName}',
          style: theme.textTheme.titleLarge?.copyWith(
            color: cs.onPrimary,
          ),
        ),
        backgroundColor: cs.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation_rounded),
            onPressed: () {
              // Open in maps app
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Opening maps app...'),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.storeLocation,
              zoom: 14,
            ),
            polylines: widget.polylines,
            markers: {
              Marker(
                markerId: const MarkerId("store"),
                position: widget.storeLocation,
                infoWindow: InfoWindow(title: widget.storeName),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              ),
              if (widget.userPosition != null)
                Marker(
                  markerId: const MarkerId("user"),
                  position: LatLng(
                    widget.userPosition!.latitude,
                    widget.userPosition!.longitude,
                  ),
                  infoWindow: const InfoWindow(title: "Your Location"),
                ),
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _updateCameraPosition();
            },
          ),

          // Floating buttons
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'btn1',
                  mini: true,
                  backgroundColor: cs.surface,
                  foregroundColor: cs.primary,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _mapController?.animateCamera(
                      CameraUpdate.zoomIn(),
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'btn2',
                  mini: true,
                  backgroundColor: cs.surface,
                  foregroundColor: cs.primary,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _mapController?.animateCamera(
                      CameraUpdate.zoomOut(),
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(height: 8),
                FloatingActionButton(
                  heroTag: 'btn3',
                  backgroundColor: cs.surface,
                  foregroundColor: cs.primary,
                  onPressed: _updateCameraPosition,
                  child: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ),

          // Distance info card
          if (widget.userPosition != null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.directions_car_rounded,
                      color: cs.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distance',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          Text(
                            _calculateDistance() ?? 'Calculating...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Open in maps app
                        HapticFeedback.mediumImpact();
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.navigation_rounded,
                          color: cs.primary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _updateCameraPosition() {
    if (widget.userPosition != null && _mapController != null) {
      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          widget.userPosition!.latitude < widget.storeLocation.latitude
              ? widget.userPosition!.latitude
              : widget.storeLocation.latitude,
          widget.userPosition!.longitude < widget.storeLocation.longitude
              ? widget.userPosition!.longitude
              : widget.storeLocation.longitude,
        ),
        northeast: LatLng(
          widget.userPosition!.latitude > widget.storeLocation.latitude
              ? widget.userPosition!.latitude
              : widget.storeLocation.latitude,
          widget.userPosition!.longitude > widget.storeLocation.longitude
              ? widget.userPosition!.longitude
              : widget.storeLocation.longitude,
        ),
      );

      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  String? _calculateDistance() {
    if (widget.userPosition == null) return null;

    final distance = Geolocator.distanceBetween(
      widget.userPosition!.latitude,
      widget.userPosition!.longitude,
      widget.storeLocation.latitude,
      widget.storeLocation.longitude,
    );

    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} meters';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }
}
class MediaGalleryScreen extends StatelessWidget {
  final Store store;

  const MediaGalleryScreen({
    super.key,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Prepare media list
    List<String> mediaUrls = [store.imageUrl];
    if (store.videos != null && store.videos!.isNotEmpty) {
      mediaUrls.addAll(store.videos!.map((video) => video.url));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Media Gallery',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: mediaUrls.length,
        itemBuilder: (context, index) {
          final url = mediaUrls[index];
          final bool isVideo = index > 0 && store.videos != null;

          return GestureDetector(
            onTap: () {
              // Show full screen image or video
              if (isVideo) {
                _showFullScreenVideo(context, url);
              } else {
                _showFullScreenImage(context, url);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail
                    isVideo
                        ? _buildVideoThumbnail(url)
                        : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[800]!,
                        highlightColor: Colors.grey[700]!,
                        child: Container(color: Colors.grey[800]),
                      ),
                    ),

                    // Overlay indicators
                    if (isVideo)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Video',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoThumbnail(String videoUrl) {
    String? videoId = YoutubePlayer.convertUrlToId(videoUrl);
    String thumbnailUrl = videoId != null
        ? 'https://img.youtube.com/vi/$videoId/0.jpg'
        : '';

    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Shimmer.fromColors(
        baseColor: Colors.grey[800]!,
        highlightColor: Colors.grey[700]!,
        child: Container(color: Colors.grey[800]),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[800],
        child: const Icon(
          Icons.video_library_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, _, __) {
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              color: Colors.black,
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showFullScreenVideo(BuildContext context, String videoUrl) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    String? videoId = YoutubePlayer.convertUrlToId(videoUrl);
    if (videoId != null) {
      YoutubePlayerController controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
        ),
      );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
            ),
            body: Center(
              child: YoutubePlayer(
                controller: controller,
                showVideoProgressIndicator: true,
                progressIndicatorColor: cs.error,
                progressColors: ProgressBarColors(
                  playedColor: cs.error,
                  handleColor: cs.error,
                ),
                onEnded: (metaData) {
                  Navigator.pop(context);
                },
              ),
            ),
          ),
        ),
      ).then((_) {
        controller.dispose();
      });
    }
  }
}

/// Circular bar button over the cover photo: frosted dark while the photo
/// shows, plain tinted icon once the bar has collapsed.
class _HeroBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool solid;
  final Color? color;

  const _HeroBarButton({required this.icon, required this.onTap, this.solid = false, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ZingPressable(
      onTap: onTap,
      pressedScale: 0.88,
      child: AnimatedSwitcher(
        duration: ZingMotion.fast,
        child: solid
            ? SizedBox(
                key: const ValueKey('solid'),
                width: 36,
                height: 36,
                child: Icon(icon, color: color ?? cs.primary, size: 22),
              )
            : ZingGlass(
                key: const ValueKey('glass'),
                borderRadius: BorderRadius.circular(100),
                color: Colors.black,
                opacity: 0.32,
                blur: 16,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(icon, color: color ?? Colors.white, size: 19),
                ),
              ),
      ),
    );
  }
}
