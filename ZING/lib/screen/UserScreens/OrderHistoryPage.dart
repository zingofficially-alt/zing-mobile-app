import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import 'package:zing/Service/OrderProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Widgets/Recommendations/RecommendedStoresRow.dart';
import '../../Service/CoustomUserProvider.dart';

class OrderHistoryPage extends StatefulWidget {
  /// When true, hides the back button so the page can serve as a root tab.
  final bool isRootTab;

  const OrderHistoryPage({Key? key, this.isRootTab = false}) : super(key: key);

  @override
  _OrderHistoryPageState createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> with SingleTickerProviderStateMixin {
  Future<List<Orders>>? _orderFuture;
  bool _isLoading = true;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);

      final CustomUser? user = userProvider.currentUser;
      if (user != null) {
        _orderFuture = orderProvider.fetchUserOrdersAcrossStores(user.id);
        await _orderFuture; // Wait for it to complete
      }
    } catch (e) {
      print('Error loading orders: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Fetch post-order store recommendations
        Provider.of<RecommendationProvider>(context, listen: false)
            .fetchRecommendations(
          placement: RecommendationProvider.postOrderStores,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<CustomUserProvider>(context);
    final storeProvider = Provider.of<StoreProvider>(context);
    final CustomUser? user = userProvider.currentUser;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        title: Text('Order History'),
        centerTitle: true,
        leading: widget.isRootTab
            ? null
            : IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                ),
                onPressed: () => Navigator.pop(context),
              ),
        automaticallyImplyLeading: !widget.isRootTab,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: user == null
          ? _buildUserNotFoundState()
          : RefreshIndicator(
        key: _refreshIndicatorKey,
        color: cs.primary,
        backgroundColor: cs.surface,
        onRefresh: _loadOrders,
        child: FutureBuilder<List<Orders>>(
          future: _orderFuture,
          builder: (context, orderSnapshot) {
            if (orderSnapshot.connectionState == ConnectionState.waiting && _isLoading) {
              return _buildLoadingState();
            } else if (orderSnapshot.hasError) {
              return _buildErrorState(orderSnapshot.error.toString());
            } else if (!orderSnapshot.hasData || orderSnapshot.data!.isEmpty) {
              return _buildEmptyState();
            } else {
              return _buildOrderList(context, orderSnapshot.data!, storeProvider);
            }
          },
        ),
      ),
    );
  }

  // Loading state with shimmer effect
  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: List.generate(
          3,
              (index) => Shimmer.fromColors(
            baseColor: cs.surfaceContainerHighest,
            highlightColor: cs.surface,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              height: 200,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // User not found state
  Widget _buildUserNotFoundState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 80,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'User Not Found',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t find your user profile. Please try logging in again.',
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
              Navigator.of(context).pushReplacementNamed('/login');
            },
            icon: const Icon(Icons.login),
            label: Text(
              'Login',
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

  // Error state
  Widget _buildErrorState(String errorMessage) {
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
            Text(
              'Something went wrong while loading your orders',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                _refreshIndicatorKey.currentState?.show();
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
      ),
    );
  }

  // Empty state
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
              Icons.shopping_bag_outlined,
              size: 80,
              color: cs.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 24),
            Text(
              'No Orders Yet',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You haven\'t placed any orders yet. Start shopping to see your order history here!',
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
                // Navigate to home to shop
                if (!widget.isRootTab) Navigator.pop(context);
                HapticFeedback.mediumImpact();
              },
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(
                'Start Shopping',
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

  // Store error card
  Widget _buildErrorCard(String orderId) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: cs.error.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline,
              color: cs.error,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order Error',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invalid store ID for order $orderId',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Main order list
  Widget _buildOrderList(BuildContext context, List<Orders> orders, StoreProvider storeProvider) {
    return AnimationLimiter(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        // +1 for the recommendations row at the bottom
        itemCount: orders.length + 1,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          // Last item: recommendations row
          if (index == orders.length) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: RecommendedStoresRow(
                placement: RecommendationProvider.postOrderStores,
                sectionTitle: "More Stores You'll Love",
              ),
            );
          }

          final order = orders[index];

          // Check if storeId is valid before fetching the store
          if (order.storeId == null || order.storeId.isEmpty) {
            print('Invalid storeId for order: ${order.id}');
            return AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 500),
              child: SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(
                  child: _buildErrorCard(order.id),
                ),
              ),
            );
          }

          return AnimationConfiguration.staggeredList(
            position: index,
            duration: const Duration(milliseconds: 500),
            child: SlideAnimation(
              verticalOffset: 50.0,
              child: FadeInAnimation(
                child: FutureBuilder<Store?>(
                  future: storeProvider.getStoreById(order.storeId),
                  builder: (context, storeSnapshot) {
                    String storeName = 'Unknown Store';
                    String storeImage = '';

                    if (storeSnapshot.hasError) {
                      storeName = 'Error fetching store';
                      print('Error fetching store: ${storeSnapshot.error}');
                    } else if (storeSnapshot.hasData && storeSnapshot.data != null) {
                      storeName = storeSnapshot.data!.name;
                      storeImage = storeSnapshot.data!.imageUrl;
                    }

                    return _buildOrderCard(context, order, storeName, storeImage);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Enhanced order card
  Widget _buildOrderCard(BuildContext context, Orders order, String storeName, String storeImage) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Get appropriate status color
    Color statusColor = _getStatusColor(order.status);
    IconData statusIcon = _getStatusIcon(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: ZingShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order header
          _buildEnhancedOrderHeader(order, storeName, storeImage, statusColor, statusIcon),

          // Divider
          Divider(
            color: cs.outline.withOpacity(0.3),
            thickness: 1,
            height: 1,
          ),

          // Product list
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Items',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _buildEnhancedProductList(order.products),
              ],
            ),
          ),

          // Divider
          Divider(
            color: cs.outline.withOpacity(0.3),
            thickness: 1,
            height: 1,
          ),

          // Order footer
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildEnhancedOrderFooter(order),
          ),
        ],
      ),
    );
  }

  // Enhanced order header
  Widget _buildEnhancedOrderHeader(
      Orders order,
      String storeName,
      String storeImage,
      Color statusColor,
      IconData statusIcon
      ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final DateFormat dateFormatter = DateFormat.yMMMd();
    final formattedDate = dateFormatter.format(order.placedAt.toDate());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          // Store image or placeholder
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.surfaceContainerHighest,
              image: storeImage.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(storeImage),
                fit: BoxFit.cover,
              )
                  : null,
              boxShadow: ZingShadows.soft,
            ),
            child: storeImage.isEmpty
                ? Icon(
              Icons.store_rounded,
              color: cs.onSurfaceVariant,
              size: 24,
            )
                : null,
          ),

          const SizedBox(width: 16),

          // Order details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  storeName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Order #${order.id.substring(0, Math.min(8, order.id.length))}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  statusIcon,
                  size: 14,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Text(
                  order.status,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced product list
  Widget _buildEnhancedProductList(List<Product> products) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: products.asMap().entries.map((entry) {
        final index = entry.key;
        final product = entry.value;

        return Container(
          margin: EdgeInsets.only(bottom: index < products.length - 1 ? 8 : 0),
          child: Row(
            children: [
              // Product indicator
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary,
                ),
              ),

              const SizedBox(width: 8),

              // Product name
              Expanded(
                child: Text(
                  product.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface,
                  ),
                ),
              ),

              const SizedBox(width: 8),

            ],
          ),
        );
      }).toList(),
    );
  }

  // Enhanced order footer
  Widget _buildEnhancedOrderFooter(Orders order) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        // Total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.onSurface,
              ),
            ),
            Text(
              '\$${order.totalPrice.toStringAsFixed(2)}',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.primary,
              ),
            ),
          ],
        ),

        // Order actions
        const SizedBox(height: 16),
        Row(
          children: [
            // Track order button (for orders in progress)
            if (order.status != 'Delivered' && order.status != 'Cancelled')
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to order tracking
                    HapticFeedback.mediumImpact();
                  },
                  icon: const Icon(Icons.location_on_outlined, size: 18),
                  label: Text(
                    'Track Order',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: cs.onPrimary,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // Reorder button (for all orders)
            Expanded(
              child: order.status != 'Delivered' && order.status != 'Cancelled'
                  ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: OutlinedButton.icon(
                  onPressed: () {
                    // Reorder functionality
                    HapticFeedback.mediumImpact();
                  },
                  icon: const Icon(Icons.replay, size: 18),
                  label: Text(
                    'Reorder',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: cs.primary,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              )
                  : ElevatedButton.icon(
                onPressed: () {
                  // Reorder functionality
                  HapticFeedback.mediumImpact();
                },
                icon: const Icon(Icons.replay, size: 18),
                label: Text(
                  'Reorder',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Helper method to get status color
  Color _getStatusColor(String status) {
    final cs = Theme.of(context).colorScheme;
    switch (status.toLowerCase()) {
      case 'delivered':
        return ZingColors.success;
      case 'processing':
      case 'prepared':
      case 'on the way':
        return ZingColors.warning;
      case 'cancelled':
        return cs.error;
      case 'pending':
        return cs.tertiary;
      default:
        return cs.primary;
    }
  }

  // Helper method to get status icon
  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'delivered':
        return Icons.check_circle_outline;
      case 'processing':
        return Icons.hourglass_top;
      case 'prepared':
        return Icons.restaurant;
      case 'on the way':
        return Icons.delivery_dining;
      case 'cancelled':
        return Icons.cancel_outlined;
      case 'pending':
        return Icons.pending_outlined;
      default:
        return Icons.info_outline;
    }
  }
}

// Add this for the Math.min functionality
class Math {
  static int min(int a, int b) {
    return a < b ? a : b;
  }
}
