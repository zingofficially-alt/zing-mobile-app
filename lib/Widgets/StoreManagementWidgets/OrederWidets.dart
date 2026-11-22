import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Modal/CoustomUser.dart';
import '../../Service/OrderProvider.dart';
import '../../Service/ThemeProvider.dart';

class EnhancedOrderManagementPage extends StatefulWidget {
  final String storeId;

  const EnhancedOrderManagementPage({Key? key, required this.storeId}) : super(key: key);

  @override
  State<EnhancedOrderManagementPage> createState() => _EnhancedOrderManagementPageState();
}

class _EnhancedOrderManagementPageState extends State<EnhancedOrderManagementPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<Orders> _cachedOrders = [];
  String _selectedFilter = 'All';

  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late Animation<double> _fadeAnimation;

  final List<String> _filterOptions = ['All', 'Pending', 'Processed', 'Shipped', 'Delivered', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    // Defer fetchOrdersByStore until after the first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchOrdersByStore();
    });
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  Future<void> fetchOrdersByStore() async {
    setState(() => _isLoading = true);

    try {
      debugPrint("Fetching orders for store: ${widget.storeId}");

      final rows = await Supabase.instance.client
          .from('orders')
          .select(Orders.select)
          .eq('store_id', widget.storeId)
          .order('placed_at', ascending: false);

      final fetchedOrders =
          (rows as List).map((r) => Orders.fromRow(r)).toList();

      setState(() => _cachedOrders = fetchedOrders);

      _fadeController.forward();
      await Future.delayed(const Duration(milliseconds: 200));
      _staggerController.forward();
    } catch (e, stackTrace) {
      debugPrint("Error fetching orders: $e\n$stackTrace");
      _showErrorSnackBar('Error fetching orders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: cs.onError),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text(message),
          ],
        ),
        backgroundColor: ZingColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<Orders> get _filteredOrders {
    if (_selectedFilter == 'All') return _cachedOrders;
    return _cachedOrders.where((order) => order.status == _selectedFilter).toList();
  }

  Map<String, int> get _orderStats {
    final stats = <String, int>{};
    for (final status in _filterOptions.skip(1)) {
      stats[status] = _cachedOrders.where((order) => order.status == status).length;
    }
    return stats;
  }

  Color _getStatusColor(String status) {
    final cs = Theme.of(context).colorScheme;
    switch (status.toLowerCase()) {
      case 'pending':
        return ZingColors.warning;
      case 'processed':
        return cs.primary;
      case 'shipped':
        return cs.tertiary;
      case 'delivered':
        return ZingColors.success;
      case 'cancelled':
        return cs.error;
      default:
        return cs.onSurfaceVariant;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'processed':
        return Icons.inventory_rounded;
      case 'shipped':
        return Icons.local_shipping_rounded;
      case 'delivered':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      default:
        return Icons.help_rounded;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final icon = _getStatusIcon(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary,
            cs.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: cs.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Overview',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_cachedOrders.length} total orders',
                    style: TextStyle(
                      color: cs.onPrimary.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: _orderStats.entries.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.onPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: TextStyle(
                          color: cs.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final filter = _filterOptions[index];
          final isSelected = _selectedFilter == filter;

          return Container(
            margin: EdgeInsets.only(
              left: index == 0 ? 0 : 8,
              right: index == _filterOptions.length - 1 ? 0 : 8,
            ),
            child: FilterChip(
              selected: isSelected,
              label: Text(
                filter,
                style: TextStyle(
                  color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: cs.surface,
              selectedColor: cs.primary,
              checkmarkColor: cs.onPrimary,
              elevation: isSelected ? 4 : 2,
              shadowColor: isSelected
                  ? cs.primary.withOpacity(0.3)
                  : Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
                side: BorderSide(
                  color: isSelected
                      ? cs.primary
                      : cs.outlineVariant,
                ),
              ),
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderCard(Orders order, int index) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnimatedBuilder(
      animation: _staggerController,
      builder: (context, child) {
        final animation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            (index * 0.1).clamp(0.0, 1.0),
            ((index * 0.1) + 0.6).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ));

        final slideAnimation = Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            (index * 0.1).clamp(0.0, 1.0),
            ((index * 0.1) + 0.6).clamp(0.0, 1.0),
            curve: Curves.easeOutCubic,
          ),
        ));

        return SlideTransition(
          position: slideAnimation,
          child: FadeTransition(
            opacity: animation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.all(20),
                  childrenPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _getStatusColor(order.status).withOpacity(0.1),
                              _getStatusColor(order.status).withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          color: _getStatusColor(order.status),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order.id.substring(0, 8).toUpperCase()}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: cs.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              order.userDetails?.name ?? 'Unknown Customer',
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildStatusBadge(order.status),
                          const SizedBox(height: 8),
                          Text(
                            '\$${order.totalPrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: ZingColors.success,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  children: [
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildOrderDetails(order),
                          const SizedBox(height: 24),
                          _buildActionButtons(order),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOrderDetails(Orders order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Customer Info
        _buildDetailSection(
          'Customer Information',
          Icons.person_rounded,
          [
            'Name: ${order.userDetails?.name ?? 'Unknown'}',
            'Phone: ${order.userDetails?.phoneNumber ?? 'Unknown'}',
            'Delivery: ${order.deliveryMethod}',
          ],
        ),

        const SizedBox(height: 20),

        // Products
        _buildDetailSection(
          'Order Items',
          Icons.shopping_bag_rounded,
          order.products.map((product) =>
          '${product.name} - \$${product.price.toStringAsFixed(2)}'
          ).toList(),
        ),

        const SizedBox(height: 20),

        // Order Info
        _buildDetailSection(
          'Order Details',
          Icons.info_rounded,
          [
            'Placed: ${order.placedAt}',
            'Total: \$${order.totalPrice.toStringAsFixed(2)}',
          ],
        ),
      ],
    );
  }

  Widget _buildDetailSection(String title, IconData icon, List<String> details) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: cs.primary, size: 18),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...details.map((detail) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            detail,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildActionButtons(Orders order) {
    final cs = Theme.of(context).colorScheme;

    if (order.status == 'Delivered' || order.status == 'Cancelled') {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (order.status == 'Pending') ...[
          Expanded(
            child: _buildActionButton(
              'Mark Processed',
              Icons.inventory_rounded,
              cs.primary,
                  () => _updateOrderStatus(order, 'Processed'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (order.status == 'Processed') ...[
          Expanded(
            child: _buildActionButton(
              'Mark Shipped',
              Icons.local_shipping_rounded,
              cs.tertiary,
                  () => _updateOrderStatus(order, 'Shipped'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        if (order.status == 'Shipped') ...[
          Expanded(
            child: _buildActionButton(
              'Mark Delivered',
              Icons.check_circle_rounded,
              ZingColors.success,
                  () => _updateOrderStatus(order, 'Delivered'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: _buildActionButton(
            'Cancel Order',
            Icons.cancel_rounded,
            cs.error,
                () => _updateOrderStatus(order, 'Cancelled'),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String text, IconData icon, Color color, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(Orders order, String newStatus) async {
    try {
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      await orderProvider.updateOrderStatus(order.storeId, order.id, newStatus);

      setState(() {
        order.status = newStatus;
      });

      _showSuccessSnackBar('Order status updated to $newStatus');
    } catch (e) {
      _showErrorSnackBar('Error updating order status: $e');
    }
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.outlineVariant,
                    cs.onSurfaceVariant,
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.receipt_long_rounded,
                color: cs.onPrimary,
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Orders Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'All'
                  ? 'Your orders will appear here once customers start placing them'
                  : 'No orders with status "$_selectedFilter" found',
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.tertiary],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(cs.onPrimary),
                strokeWidth: 3,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading Orders...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Order Management',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: cs.onPrimary,
          ),
        ),
        backgroundColor: cs.onSurface,
        elevation: 0,
        iconTheme: IconThemeData(color: cs.onPrimary),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.onSurface,
              cs.surface,
            ],
            stops: const [0.0, 0.3],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingState()
              : _filteredOrders.isEmpty
              ? _buildEmptyState()
              : FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildStatsCard(),
                      _buildFilterChips(),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    itemCount: _filteredOrders.length,
                    itemBuilder: (context, index) {
                      return _buildOrderCard(_filteredOrders[index], index);
                    },
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

// Usage for backward compatibility
class OrderManagementPage extends StatelessWidget {
  final String storeId;

  const OrderManagementPage({Key? key, required this.storeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return EnhancedOrderManagementPage(storeId: storeId);
  }
}
