import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../Modal/CoustomUser.dart';
import '../../Service/CoustomUserProvider.dart';
import '../../Service/StoreProvider.dart';
import '../../Service/ThemeProvider.dart';
import '../StoreScreen/StoreScreen.dart';

class FavouriteStoreScreen extends StatefulWidget {
  final bool showAppBar; // Option to hide app bar when embedded

  const FavouriteStoreScreen({Key? key, this.showAppBar = true}) : super(key: key);

  @override
  _FavouriteStoreScreenState createState() => _FavouriteStoreScreenState();
}

class _FavouriteStoreScreenState extends State<FavouriteStoreScreen> with SingleTickerProviderStateMixin {
  Future<List<Store>>? _favoriteStoresFuture;
  CustomUser? currentUser; // Made nullable to handle logged-out state
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  late AnimationController _animationController;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadFavoriteStores();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadFavoriteStores() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final customUserProvider = Provider.of<CustomUserProvider>(context, listen: false);
      currentUser = customUserProvider.user;

      // If no user is logged in, show empty state
      if (currentUser == null) {
        _favoriteStoresFuture = Future.value([]);
        return;
      }

      if (currentUser!.favorites == null) {
        currentUser!.favorites = [];
      }

      _favoriteStoresFuture = _fetchFavoriteStores(currentUser!.favorites!);
      await _favoriteStoresFuture;
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load favorite stores: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<Store>> _fetchFavoriteStores(List<String> favoriteStoreIds) async {
    if (favoriteStoreIds.isEmpty) {
      return [];
    }

    // Get StoreProvider to use its fetchStore method which properly fetches products
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    List<Store> favoriteStores = [];

    for (String storeId in favoriteStoreIds) {
      try {
        // Use StoreProvider's fetchStore method which properly fetches products from subcollection
        Store? store = await storeProvider.fetchStore(storeId);
        if (store != null) {
          favoriteStores.add(store);
        }
      } catch (e) {
        print('Error fetching store $storeId: $e');
        // Continue with other stores
      }
    }

    return favoriteStores;
  }

  void _navigateToStoreScreen(Store store, CustomUser? user) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoreDetailScreen(store: store, user: user),
      ),
    ).then((_) {
      // Refresh the list when returning from the store details screen
      _refreshIndicatorKey.currentState?.show();
    });
  }

  Future<void> _removeFromFavorites(Store store) async {
    // Check if user is logged in
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final customUserProvider = Provider.of<CustomUserProvider>(context, listen: false);
      // Remove the await since this method returns void
      customUserProvider.removeFavoriteStore(store.id!);

      // Update the local list
      setState(() {
        currentUser?.favorites?.remove(store.id);
      });

      final cs = Theme.of(context).colorScheme;
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: cs.onPrimary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${store.name} removed from favorites',
                ),
              ),
            ],
          ),
          backgroundColor: ZingColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: cs.onPrimary,
            onPressed: () {
              // Add back to favorites
              customUserProvider.addFavoriteStore(store.id!);
              _refreshIndicatorKey.currentState?.show();
            },
          ),
        ),
      );

      // Refresh the list
      _loadFavoriteStores();
    } catch (e) {
      final cs = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: cs.onError,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: const Text(
                  'Failed to remove from favorites',
                ),
              ),
            ],
          ),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: widget.showAppBar ? AppBar(
        elevation: 0,
        title: Text('Favorite Stores'),
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        actions: [
          if (_favoriteStoresFuture != null)
            FutureBuilder<List<Store>>(
              future: _favoriteStoresFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: Text(
                        '${snapshot.data!.length}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ) : null, // Hide app bar when embedded in HomeScreen
      body: SafeArea(
        top: !widget.showAppBar, // Add top safe area only when app bar is hidden
        child: _isLoading && _favoriteStoresFuture == null
            ? _buildLoadingState()
            : _hasError
            ? _buildErrorState()
            : _buildContent(),
      ),
    );
  }

  // Loading state with animation
  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitPulse(
            color: cs.primary,
            size: 70.0,
          ),
          const SizedBox(height: 24),
          Text(
            'Loading favorites...',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Error state with retry button
  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 80,
            color: cs.error.withOpacity(0.8),
          ),
          const SizedBox(height: 24),
          Text(
            'Oops!',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Something went wrong while loading your favorite stores.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              _loadFavoriteStores();
              HapticFeedback.mediumImpact();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Try Again',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.onPrimary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  // Main content with favorites list
  Widget _buildContent() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      color: cs.primary,
      backgroundColor: cs.surface,
      onRefresh: _loadFavoriteStores,
      displacement: 40,
      child: FutureBuilder<List<Store>>(
        future: _favoriteStoresFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
            return _buildLoadingState();
          } else if (snapshot.hasError) {
            return _buildErrorState();
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          } else {
            List<Store> favoriteStores = snapshot.data!;

            // Add extra bottom padding when embedded in HomeScreen to account for bottom nav bar
            final bottomPadding = widget.showAppBar ? 32.0 : 100.0;

            return AnimationLimiter(
              child: ListView.builder(
                padding: EdgeInsets.only(top: 16, bottom: bottomPadding, left: 16, right: 16),
                itemCount: favoriteStores.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  Store store = favoriteStores[index];

                  return AnimationConfiguration.staggeredList(
                    position: index,
                    duration: const Duration(milliseconds: 500),
                    child: SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(
                        child: _buildStoreCard(store, index),
                      ),
                    ),
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }

  // Empty state with illustration
  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border_rounded,
              size: 100,
              color: cs.secondary.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'No Favorites Yet',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You haven\'t added any stores to your favorites yet. Explore stores and tap the heart icon to add them here!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                height: 1.5,
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to home to explore stores
                Navigator.pop(context);
                HapticFeedback.mediumImpact();
              },
              icon: const Icon(Icons.explore_outlined),
              label: Text(
                'Explore Stores',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.onPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Store card widget
  Widget _buildStoreCard(Store store, int index) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Dismissible(
      key: Key(store.id ?? 'store-$index'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.delete_outline,
          color: cs.onError,
          size: 28,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Remove from Favorites?',
              style: theme.textTheme.headlineSmall,
            ),
            content: Text(
              'Are you sure you want to remove ${store.name} from your favorites?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Remove',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onError,
                  ),
                ),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        _removeFromFavorites(store);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ZingShadows.soft,
        ),
        child: InkWell(
          onTap: () => _navigateToStoreScreen(store, currentUser),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Store Image
                Hero(
                  tag: 'store-image-${store.id}',
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          spreadRadius: 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: CachedNetworkImage(
                        imageUrl: store.imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: cs.surfaceContainerHighest,
                          child: const Center(
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(
                            Icons.store_rounded,
                            size: 40,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Store Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Store name
                          Expanded(
                            child: Text(
                              store.name,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: cs.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // Rating
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ZingColors.warning.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star_rounded,
                                  color: ZingColors.warning,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${store.ratings ?? 4.5}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Category badge
                      if (store.category != null && store.category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            store.category,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: cs.primary,
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      // Store description
                      Text(
                        store.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Product count and view button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Product count
                          Row(
                            children: [
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 14,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${store.products.length} Products',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),

                          // View button
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: cs.onPrimary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 12,
                                  color: cs.onPrimary,
                                ),
                              ],
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
        ),
      ),
    );
  }
}
