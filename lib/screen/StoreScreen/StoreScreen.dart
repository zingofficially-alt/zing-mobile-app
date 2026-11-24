import 'dart:convert';
import 'dart:ui';
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

import '../../Chat/ChatScreen.dart';
import '../../Modal/CoustomUser.dart'; // Make sure this import matches your project structure
import '../../Service/StoreProvider.dart';
import '../../Service/RecommendationProvider.dart';
import '../../Service/ThemeProvider.dart';
import '../../screen/StoreScreen/ProductDetailsScreen.dart';
import '../../Widgets/Recommendations/RecommendedProductsRow.dart';

import 'customCarousel.dart';
import '../../config/env.dart';

class StoreDetailScreen extends StatefulWidget {
  final Store store;
  final CustomUser? user; // Made optional to allow browsing without login

  const StoreDetailScreen({
    Key? key,
    required this.store,
    this.user, // No longer required
  }) : super(key: key);

  @override
  _StoreDetailScreenState createState() => _StoreDetailScreenState();
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
  YoutubePlayerController? _youtubeController;
  bool _showingVideo = false;

  @override
  void initState() {
    super.initState();
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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
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
    final isScrolled = _scrollController.offset > 180;
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
      setState(() {
        _isFavorite = !_isFavorite;
      });

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating favorites'),
          backgroundColor: cs.error,
        ),
      );
    });
  }

  // Show login dialog when user tries to perform account-based actions
  Future<bool> _showLoginDialog() async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _userPosition = position;
        _getDirections();
      });
    } catch (e) {
      print("Error getting user location: $e");
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
      print('Error fetching directions');
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
                    color: Colors.black.withOpacity(0.1),
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
                    itemBuilder: (context, _) => Icon(
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
      final theme = Theme.of(context);
      final cs = theme.colorScheme;

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
    if (_productCategories == null || _selectedProductCategoryIndex == 0) {
      // "All" category
      return widget.store.products;
    } else {
      final selectedCategory = _productCategories![_selectedProductCategoryIndex];
      return widget.store.products.where((p) => p.description == selectedCategory).toList();
    }
  }

  // --------------------------------------------------------------------------
  // BUILD THE UI
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildDynamicAppBar(),
      body: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Store header with hero image
          SliverToBoxAdapter(
            child: _buildStoreHeader(),
          ),

          // Quick actions
          SliverToBoxAdapter(
            child: _buildQuickActions(),
          ),

          // Store videos (if available)

            SliverToBoxAdapter(
              child: _buildMediaCarouselSection(),
            ),

          // Store details
          SliverToBoxAdapter(
            child: _buildStoreDetails(),
          ),

          // Map section
          SliverToBoxAdapter(
            child: _buildLocationSection(),
          ),

          // Product section
          SliverToBoxAdapter(
            child: _buildProductsHeader(),
          ),

          // Product grid
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 8),
            sliver: _buildProductGrid(_getFilteredProducts()),
          ),

          // AI-powered product recommendations
          SliverToBoxAdapter(
            child: RecommendedProductsRow(
              placement: RecommendationProvider.storeAlsoViewed,
              sectionTitle: 'You May Also Like',
              fallbackProducts: widget.store.products,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      floatingActionButton: _buildChatFAB(),
    );
  }

  // Dynamic app bar that changes on scroll
  PreferredSizeWidget _buildDynamicAppBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppBar(
      backgroundColor: _isScrolled ? cs.primary : Colors.transparent,
      elevation: _isScrolled ? 4 : 0,
      title: AnimatedOpacity(
        opacity: _isScrolled ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        child: Text(
          widget.store.name,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: cs.onPrimary,
          ),
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isScrolled
                ? Colors.white.withOpacity(0.2)
                : Colors.black.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 18,
          ),
        ),
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
        },
      ),
      actions: [
        // Favorite button
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isScrolled
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? cs.error : Colors.white,
              size: 18,
            ),
          ),
          onPressed: () {
            HapticFeedback.mediumImpact();
            _toggleFavorite();
          },
        ),

        // Share button
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isScrolled
                  ? Colors.white.withOpacity(0.2)
                  : Colors.black.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.share_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          onPressed: () {
            HapticFeedback.mediumImpact();
            _shareStore();
          },
        ),
        const SizedBox(width: 8),
      ],
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  // Store header with cover image
  Widget _buildStoreHeader() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return FadeIn(
      duration: const Duration(milliseconds: 400),
      child: Stack(
        children: [
          // Header background image with gradient overlay
          CachedNetworkImage(
            imageUrl: widget.store.imageUrl,
            height: screenHeight * 0.45,
            width: screenWidth,
            fit: BoxFit.cover,
            placeholder: (context, url) => Shimmer.fromColors(
              baseColor: cs.surfaceContainerHighest,
              highlightColor: cs.surface,
              child: Container(
                color: cs.surface,
                height: screenHeight * 0.45,
                width: screenWidth,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              height: screenHeight * 0.45,
              width: screenWidth,
              color: cs.primary,
              child: Icon(
                Icons.image_not_supported_rounded,
                color: cs.onPrimary.withOpacity(0.5),
                size: 60,
              ),
            ),
          ),

          // Gradient overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                    Colors.black.withOpacity(0.8),
                  ],
                  stops: const [0.1, 0.6, 0.95],
                ),
              ),
            ),
          ),

          // Store info
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Category badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ZingColors.success,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.store_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.store.category,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 10),

                    // Open/Closed badge (placeholder - you would implement actual logic)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ZingColors.success.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'OPEN',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Store name
                Text(
                  widget.store.name,
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),

                const SizedBox(height: 8),

                // Store description
                Text(
                  widget.store.description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 10),

                // Rating
                Row(
                  children: [
                    RatingBarIndicator(
                      rating: _averageRating,
                      itemBuilder: (context, index) => Icon(
                        Icons.star_rounded,
                        color: ZingColors.warning,
                      ),
                      itemCount: 5,
                      itemSize: 20.0,
                      direction: Axis.horizontal,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _averageRating.toStringAsFixed(1),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${widget.store.ratings.length} reviews)',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Quick action buttons
  Widget _buildQuickActions() {
    return FadeInUp(
      from: 20,
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 100),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickActionButton(
              icon: Icons.call_rounded,
              label: 'Call',
              onTap: () {
                // Call store
                HapticFeedback.mediumImpact();
                _launchPhone(widget.store.phoneNumber);
              },
            ),
            _buildQuickActionButton(
              icon: Icons.directions_rounded,
              label: 'Directions',
              onTap: () {
                // Show options for directions
                HapticFeedback.mediumImpact();
                _showDirectionsOptions();
              },
            ),
            _buildQuickActionButton(
              icon: Icons.star_rounded,
              label: 'Rate',
              onTap: _showRatingDialog,
            ),
            _buildQuickActionButton(
              icon: Icons.share_rounded,
              label: 'Share',
              onTap: _shareStore,
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
              content: Text('Unable to make phone call'),
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
            content: Text('Could not share store'),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: cs.primary,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.titleSmall?.copyWith(
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  // Video section
  Widget _buildVideoSection() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Store Videos'),
          const SizedBox(height: 16),

          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: widget.store.videos?.length ?? 0,
              itemBuilder: (context, index) {
                final video = widget.store.videos![index];

                // Try to extract thumbnail from YouTube URL
                String? videoId = YoutubePlayer.convertUrlToId(video.url);
                String thumbnailUrl = videoId != null
                    ? 'https://img.youtube.com/vi/$videoId/0.jpg'
                    : '';

                return GestureDetector(
                  onTap: () => _showYouTubeVideo(video.url),
                  child: Container(
                    width: 200,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Video thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: cs.surfaceContainerHighest,
                              highlightColor: cs.surface,
                              child: Container(color: cs.surface),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: cs.onSurface,
                              child: Icon(
                                Icons.video_library_rounded,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ),

                        // Play button overlay
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surface.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.play_arrow_rounded,
                              color: cs.primary,
                              size: 36,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Store details section
  Widget _buildStoreDetails() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FadeInUp(
      from: 20,
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 200),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Store Information'),
            const SizedBox(height: 16),

            // Contact info card
            _buildInfoCard(
              title: 'Contact Information',
              content: Column(
                children: [
                  _buildInfoRow(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value: widget.store.phoneNumber,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.person_rounded,
                    label: 'Owner',
                    value: widget.store.owner.name,
                  ),
                  const SizedBox(height: 16),
                  _buildInfoRow(
                    icon: Icons.email_rounded,
                    label: 'Email',
                    value: widget.store.owner.email,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Delivery options card
            if (widget.store.deliveryOptions != null && widget.store.deliveryOptions!.isNotEmpty)
              _buildInfoCard(
                title: 'Delivery Options',
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.store.deliveryOptions!.map((option) {
                    IconData icon;
                    Color iconColor;

                    if (option == 'Home Delivery') {
                      icon = Icons.delivery_dining_rounded;
                      iconColor = ZingColors.success;
                    } else if (option == 'Pickup') {
                      icon = Icons.shopping_bag_rounded;
                      iconColor = ZingColors.warning;
                    } else if (option == 'In-Store Shopping') {
                      icon = Icons.store_rounded;
                      iconColor = cs.primary;
                    } else {
                      icon = Icons.check_circle_rounded;
                      iconColor = ZingColors.success;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Icon(
                            icon,
                            color: iconColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option == 'Home Delivery' && widget.store.deliveryCost != null
                                  ? 'Home Delivery (Rs. ${widget.store.deliveryCost!.toStringAsFixed(2)})'
                                  : option,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessHourRow(String day, String hours, {bool isHighlighted = false}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
            color: isHighlighted ? cs.tertiary : cs.onSurface,
          ),
        ),
        Text(
          hours,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w400,
            color: isHighlighted ? cs.tertiary : cs.onSurfaceVariant,
          ),
        ),
      ],
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
                      color: Colors.black.withOpacity(0.1),
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
                                color: Colors.black.withOpacity(0.2),
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
                  color: ZingColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ZingColors.success.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
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
            content: Text('Unable to open maps application'),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FadeInUp(
      from: 20,
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Products'),
            const SizedBox(height: 16),

            // Product filtering
            if (_productCategories != null && _productCategories!.length > 1)
              SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _productCategories!.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedProductCategoryIndex = index;
                        });
                        HapticFeedback.selectionClick();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: _selectedProductCategoryIndex == index
                              ? cs.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _selectedProductCategoryIndex == index
                                ? cs.primary
                                : cs.onSurfaceVariant.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _productCategories![index],
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: _selectedProductCategoryIndex == index
                                ? cs.onPrimary
                                : cs.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Product grid
  Widget _buildProductGrid(List<Product> products) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (products.isEmpty) {
      return SliverToBoxAdapter(
        child: FadeIn(
          duration: const Duration(milliseconds: 400),
          child: Container(
            height: 200,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_basket_rounded,
                  size: 50,
                  color: cs.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No products available in this category',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            // Use a staggered animation for the product cards
            return FadeInUp(
              from: 20,
              duration: const Duration(milliseconds: 400),
              delay: Duration(milliseconds: 100 + (index * 50)),
              child: _buildProductCard(products[index]),
            );
          },
          childCount: products.length,
        ),
      ),
    );
  }

  // Enhanced product card
  Widget _buildProductCard(Product product) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: () => _openProductDetail(product),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Stack(
                children: [
                  Hero(
                    tag: 'product-${product.id}',
                    child: CachedNetworkImage(
                      imageUrl: product.imageUrl ?? '',
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: cs.surfaceContainerHighest,
                        highlightColor: cs.surface,
                        child: Container(
                          color: cs.surface,
                          height: 150,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 150,
                        color: cs.surfaceContainerHighest,
                        child: Icon(
                          Icons.image_not_supported_rounded,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  // Discount badge
                  if (product.discount != null && product.discount! > 0)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.error,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${product.discount!.toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                  // Add to cart button - Only show if product is in stock
                  if (product.isAvailable && product.quantity > 0)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.add_shopping_cart_rounded,
                            color: cs.onPrimary,
                            size: 18,
                          ),
                          onPressed: () {
                            // Add to cart logic
                            HapticFeedback.mediumImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
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
                          },
                          padding: EdgeInsets.zero,
                        ),
                      ),
                    ),

                  // Availability badge - Check both isAvailable and quantity
                  if (!product.isAvailable || product.quantity <= 0)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.6),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.error,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'OUT OF STOCK',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              // Product details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        product.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (product.description != null && product.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          product.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],

                      const Spacer(),

                      // Price with discounted price if available
                      if (product.discount != null && product.discount! > 0) ...[
                        Row(
                          children: [
                            // Calculate discounted price
                            Text(
                              'Rs. ${(product.price * (1 - product.discount! / 100)).toStringAsFixed(2)}',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rs. ${product.price.toStringAsFixed(2)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Rs. ${product.price.toStringAsFixed(2)}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ],

                      // Rating if available
                      if (product.rating != null && product.rating! > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: ZingColors.warning,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              product.rating!.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProductDetail(Product product) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ProductDetailScreen(
          product: product,
          store: widget.store,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 0.05);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // Chat FAB with animation
  Widget _buildChatFAB() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      height: 60,
      width: 60,
      child: FloatingActionButton(
        onPressed: _chatWithStore,
        backgroundColor: ZingColors.success,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        child: Icon(
          Icons.chat_rounded,
          color: cs.onPrimary,
          size: 28,
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
              child: _buildSectionTitle('Media Gallery'),
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
              loadingWidget: Container(
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Text(
      title,
      style: theme.textTheme.headlineMedium?.copyWith(
        color: cs.onSurface,
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required Widget content,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
            ),
          ),
          const Divider(height: 24),
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
    Key? key,
    required this.polylines,
    required this.storeLocation,
    this.userPosition,
    required this.storeName,
  }) : super(key: key);

  @override
  _FullScreenMapState createState() => _FullScreenMapState();
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
                SnackBar(
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
                      color: Colors.black.withOpacity(0.1),
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
                          color: cs.primary.withOpacity(0.1),
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
    Key? key,
    required this.store,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
                    color: Colors.black.withOpacity(0.2),
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
                            color: Colors.black.withOpacity(0.7),
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
