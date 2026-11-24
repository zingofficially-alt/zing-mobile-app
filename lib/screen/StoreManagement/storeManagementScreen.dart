import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/StoreManagementWidgets/OrederWidets.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Widgets/StoreManagementWidgets/BuildRenewScreen.dart';
import 'package:zing/Widgets/StoreManagementWidgets/buildAddStoreButton.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';
import 'package:zing/screen/StoreManagement/EditStoreScreen.dart';
import 'package:zing/screen/StoreManagement/EditProduct.dart';

class EnhancedStoreManagementWidget extends StatefulWidget {
  const EnhancedStoreManagementWidget({super.key});

  @override
  State<EnhancedStoreManagementWidget> createState() => _EnhancedStoreManagementWidgetState();
}

class _EnhancedStoreManagementWidgetState extends State<EnhancedStoreManagementWidget>
    with TickerProviderStateMixin {
  CustomUser? _currentUser;
  List<Product> _products = [];
  List<Orders> _recentOrders = [];
  List<Map<String, dynamic>> _recentActivities = [];
  Map<String, double> _salesData = {};
  bool _isLoading = true;
  int _daysLeft = 0;
  bool _hasAccess = true;
  int _selectedTabIndex = 0;
  int _totalCustomers = 0;
  double _totalRevenue = 0;
  int _totalOrders = 0;

  late TabController _tabController;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  SupabaseClient get _db => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initControllers();
    _fetchUserData();
    _setSystemUIOverlay();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
  }

  void _initControllers() {
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
  }

  void _setSystemUIOverlay() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;

    try {
      final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
      final currentUser = userProvider.user;

      if (currentUser != null && currentUser.store != null) {
        final storeId = currentUser.store!.id!;
        await Future.wait([
          _fetchProductsForStore(storeId),
          _fetchRecentOrders(storeId),
          _fetchCustomerCount(storeId),
          _fetchSalesData(storeId),
          _fetchRecentActivities(storeId),
          _fetchLatestPaymentAndCalculateDaysLeft(currentUser.id),
        ]);
      }

      if (!mounted) return;

      setState(() {
        _currentUser = currentUser;
        _isLoading = false;
      });

      _startAnimations();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load store data: ${e.toString()}');
      }
    }
  }

  void _startAnimations() async {
    if (!mounted) return;
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) _scaleController.forward();
  }

  Future<void> _fetchLatestPaymentAndCalculateDaysLeft(String userId) async {
    try {
      final payments = await _db
          .from('payments')
          .select('paid_at')
          .eq('user_id', userId)
          .order('paid_at', ascending: false)
          .limit(1);

      if ((payments as List).isNotEmpty) {
        final paymentDate = Timestamp.parse(payments.first['paid_at']).toDate();
        _daysLeft = CustomUser.accessDays - DateTime.now().difference(paymentDate).inDays;

        if (_daysLeft <= 0) {
          _hasAccess = false;
          _currentUser?.storeAccess = false;
        }
      } else {
        _hasAccess = false;
        _currentUser?.storeAccess = false;
      }
    } catch (e) {
      _hasAccess = false;
      _currentUser?.storeAccess = false;
    }
  }

  Future<void> _fetchProductsForStore(String storeId) async {
    try {
      final rows = await _db.from('products').select().eq('store_id', storeId);

      if (!mounted) return;

      // Full model so the owner sees the real stock count.
      final products = (rows as List).map((r) => Product.fromRow(r)).toList();

      setState(() {
        _products = products;
      });
    } catch (e) {
      debugPrint("Error fetching products: $e");
    }
  }

  Future<void> _fetchRecentOrders(String storeId) async {
    try {
      final rows = await _db
          .from('orders')
          .select(Orders.select)
          .eq('store_id', storeId)
          .order('placed_at', ascending: false)
          .limit(10);

      if (!mounted) return;

      final orders = (rows as List).map((r) => Orders.fromRow(r)).toList();

      setState(() {
        _recentOrders = orders;
        _totalOrders = orders.length;
        // Cancelled orders earn nothing.
        _totalRevenue = orders
            .where((order) => order.status != OrderStatus.cancelled)
            .fold(0, (prev, order) => prev + order.totalPrice);
      });
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    }
  }

  Future<void> _fetchCustomerCount(String storeId) async {
    try {
      final rows = await _db.from('orders').select('user_id').eq('store_id', storeId);

      final uniqueCustomers = <String>{
        for (final r in rows as List)
          if (r['user_id'] is String) r['user_id'] as String,
      };

      if (!mounted) return;
      setState(() {
        _totalCustomers = uniqueCustomers.length;
      });
    } catch (e) {
      debugPrint("Error fetching customer count: $e");
    }
  }

  Future<void> _fetchSalesData(String storeId) async {
    try {
      final now = DateTime.now();
      final lastWeek = now.subtract(const Duration(days: 7));

      final rows = await _db
          .from('orders')
          .select('placed_at, total_price, status')
          .eq('store_id', storeId)
          .gte('placed_at', lastWeek.toUtc().toIso8601String())
          .order('placed_at', ascending: true);

      final Map<String, double> salesByDay = {
        'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0,
      };

      for (final r in rows as List) {
        // Cancelled orders are not sales.
        if (r['status'] == OrderStatus.cancelled) continue;
        final placedAt = Timestamp.parse(r['placed_at']).toDate();
        final dayName = DateFormat('E').format(placedAt).substring(0, 3);
        final price = (r['total_price'] as num?)?.toDouble() ?? 0;

        salesByDay[dayName] = (salesByDay[dayName] ?? 0) + price;
      }

      if (!mounted) return;
      setState(() {
        _salesData = salesByDay;
      });
    } catch (e) {
      debugPrint("Error fetching sales data: $e");
    }
  }

  Future<void> _fetchRecentActivities(String storeId) async {
    try {
      final activities = <Map<String, dynamic>>[];

      // Recent orders
      final rows = await _db
          .from('orders')
          .select('id, placed_at, total_price, status')
          .eq('store_id', storeId)
          .order('placed_at', ascending: false)
          .limit(3);

      for (final data in rows as List) {
        final orderTime = Timestamp.parse(data['placed_at']).toDate();
        final timeDiff = DateTime.now().difference(orderTime);

        String timeAgo;
        if (timeDiff.inMinutes < 60) {
          timeAgo = '${timeDiff.inMinutes} minutes ago';
        } else if (timeDiff.inHours < 24) {
          timeAgo = '${timeDiff.inHours} hours ago';
        } else {
          timeAgo = '${timeDiff.inDays} days ago';
        }

        final total = (data['total_price'] as num?)?.toDouble() ?? 0;
        final cancelled = data['status'] == OrderStatus.cancelled;
        activities.add({
          'type': 'order',
          'title': '${cancelled ? 'Cancelled' : 'New'} order #${(data['id'] as String).substring(0, 4)}',
          'subtitle': 'Order of Rs ${total.toStringAsFixed(2)} placed',
          'time': timeAgo,
          'amount': 'Rs ${total.toStringAsFixed(2)}',
        });
      }

      if (!mounted) return;
      setState(() {
        _recentActivities = activities.take(5).toList();
      });
    } catch (e) {
      debugPrint("Error fetching activities: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error, color: cs.onPrimary),
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


  void _navigateToAddProduct() {
    if (_currentUser?.store?.id != null) {
      Navigator.push(
        context,
        zingRoute(EditProductScreen(storeId: _currentUser!.store!.id!)),
      ).then((_) {
        // Refresh products after returning from add product screen
        if (_currentUser?.store?.id != null) {
          _fetchProductsForStore(_currentUser!.store!.id!);
        }
      });
    }
  }

  void _navigateToEditProduct(Product product) {
    if (_currentUser?.store?.id != null) {
      Navigator.push(
        context,
        zingRoute(EditProductScreen(
                product: product,
                storeId: _currentUser!.store!.id!,
              )),
      ).then((_) {
        // Refresh products after returning from edit
        if (_currentUser?.store?.id != null) {
          _fetchProductsForStore(_currentUser!.store!.id!);
        }
      });
    }
  }

  void _openEditStoreDialog() {
    if (_currentUser?.store == null) return;

    showDialog(
      context: context,
      builder: (context) => AddEditStoreDialog(
        store: _currentUser!.store,
        refreshStoreData: () {
          if (_currentUser?.store?.id != null) {
            _fetchUserData();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_currentUser == null || !_currentUser!.storeAccess) {
      return _buildAccessDeniedScreen();
    }

    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildAppBar(isTablet),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildDashboardTab(isTablet),
                  _buildProductsTab(isTablet),
                  _buildOrdersTab(isTablet),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  void _openRenew() {
    final user = _currentUser;
    if (user == null) return;
    Navigator.of(context).push(zingRoute(
      Scaffold(
        appBar: AppBar(title: const Text('Subscription')),
        body: buildRenewScreen(context, user),
      ),
    ));
  }

  static String _rs(double v) => 'Rs ${NumberFormat.decimalPattern().format(v.round())}';

  /// Header: back, store name as a large title, edit, and status chips.
  Widget _buildAppBar(bool isTablet) {
    final cs = Theme.of(context).colorScheme;
    final store = _currentUser!.store!;
    final expiring = _daysLeft <= 7;

    Widget chip(String label, {IconData? icon, Color? color}) {
      final c = color ?? cs.onSurfaceVariant;
      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 12, color: c), const SizedBox(width: 5)],
            Text(label, style: ZingType.style(12, weight: FontWeight.w600, color: c)),
          ],
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (Navigator.of(context).canPop())
                  CupertinoNavigationBarBackButton(
                    color: cs.primary,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                const Spacer(),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  onPressed: _openEditStoreDialog,
                  child: Text('Edit Store', style: ZingType.body(cs.primary)),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                store.name,
                style: isTablet ? ZingType.largeTitle(cs.onSurface) : ZingType.title1(cs.onSurface),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  chip(store.isActive ? 'Live' : 'Hidden',
                      icon: CupertinoIcons.circle_fill,
                      color: store.isActive ? ZingColors.success : ZingColors.error),
                  chip('$_daysLeft ${_daysLeft == 1 ? 'day' : 'days'} left',
                      icon: CupertinoIcons.clock,
                      color: expiring ? ZingColors.warning : null),
                  chip(store.category, icon: CupertinoIcons.tag),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final labels = const ['Dashboard', 'Products', 'Orders'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ZingSegmented<int>(
        value: _selectedTabIndex,
        segments: {
          0: labels[0],
          1: '${labels[1]} (${_products.length})',
          2: labels[2],
        },
        onChanged: (i) => _tabController.animateTo(i),
      ),
    );
  }

  Widget _buildDashboardTab(bool isTablet) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        if (_daysLeft <= 7) ZingReveal(child: _buildWarningBanner()),
        ZingReveal(child: _buildStatsCards(isTablet)),
        ZingReveal(child: _buildStockAlerts()),
        const SizedBox(height: 16),
        ZingReveal(delay: const Duration(milliseconds: 60), child: _buildSalesChart()),
        const SizedBox(height: 16),
        ZingReveal(child: _buildQuickActions(isTablet)),
        const SizedBox(height: 24),
        ZingReveal(child: _buildRecentActivity()),
      ],
    );
  }

  Widget _buildWarningBanner() {
    final cs = Theme.of(context).colorScheme;
    final expired = _daysLeft <= 0;
    final color = expired ? ZingColors.error : ZingColors.warning;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ZingRadius.md),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.exclamationmark_triangle_fill, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(expired ? 'Subscription ended' : 'Subscription ending soon',
                    style: ZingType.headline(cs.onSurface)),
                const SizedBox(height: 2),
                Text(
                  expired
                      ? 'Renew to make your store visible to customers again.'
                      : 'Your store stays visible for $_daysLeft more ${_daysLeft == 1 ? 'day' : 'days'}.',
                  style: ZingType.footnote(cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ZingPressable(
            onTap: _openRenew,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(100)),
              child: Text('Renew', style: ZingType.style(15, weight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  /// Products that are sold out or nearly so, most urgent first.
  Widget _buildStockAlerts() {
    final attention = _products.where((p) => !p.inStock || p.lowStock).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
    if (attention.isEmpty) return const SizedBox.shrink();
    final shown = attention.take(4).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ZingGroupedSection(
        margin: EdgeInsets.zero,
        header: 'Needs attention',
        footer: attention.length > shown.length
            ? '${attention.length - shown.length} more low-stock products are in the Products tab.'
            : 'Tap a product to update its stock.',
        children: [
          for (final p in shown)
            ZingListRow(
              icon: p.inStock
                  ? CupertinoIcons.exclamationmark_triangle_fill
                  : CupertinoIcons.xmark_circle_fill,
              iconColor: p.inStock ? ZingColors.warning : ZingColors.error,
              title: p.name,
              subtitle: p.inStock ? 'Only ${p.quantity} left' : 'Sold out — hidden from buying',
              onTap: () => _navigateToEditProduct(p),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isTablet) {
    final cards = [
      _buildStatCard('Revenue', _rs(_totalRevenue), CupertinoIcons.chart_bar_alt_fill, ZingColors.success),
      _buildStatCard('Orders', '$_totalOrders', CupertinoIcons.bag_fill, ZingColors.warning),
      _buildStatCard('Customers', '$_totalCustomers', CupertinoIcons.person_2_fill, ZingColors.accent),
      _buildStatCard('Products', '${_products.length}', CupertinoIcons.cube_box_fill, ZingColors.primary),
    ];
    if (isTablet) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
        const SizedBox(height: 12),
        Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZingRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ZingIconTile(icon: icon, color: color, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: ZingType.subhead(cs.onSurfaceVariant).copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: ZingType.title1(cs.onSurface)),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart() {
    final cs = Theme.of(context).colorScheme;
    final weekTotal = _salesData.values.fold<double>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(ZingRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SALES THIS WEEK',
              style: ZingType.style(12, weight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(_rs(weekTotal), style: ZingType.title1(cs.onSurface)),
          const SizedBox(height: 16),
          SizedBox(height: 150, child: _buildCustomChart()),
        ],
      ),
    );
  }

  Widget _buildCustomChart() {
    final cs = Theme.of(context).colorScheme;
    if (_salesData.isEmpty || _salesData.values.every((v) => v == 0)) {
      return Center(
        child: Text('No sales yet this week', style: ZingType.subhead(cs.onSurfaceVariant)),
      );
    }
    final maxValue = _salesData.values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final entry in _salesData.entries)
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bars grow from the baseline when the chart appears.
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: maxValue > 0 ? entry.value / maxValue : 0),
                  duration: ZingMotion.slow,
                  curve: ZingMotion.emphasized,
                  builder: (_, t, __) => Container(
                    height: 4 + 116 * t,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: entry.value == maxValue ? cs.primary : cs.primary.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  entry.key,
                  style: ZingType.style(11,
                      weight: entry.value == maxValue ? FontWeight.w600 : FontWeight.w400,
                      color: entry.value == maxValue ? cs.onSurface : cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ZingSectionTitle(
          title: 'Recent Activity',
          actionLabel: _recentActivities.isEmpty ? null : 'See All',
          onAction: () => _tabController.animateTo(2),
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
        ),
        ZingGroupedSection(
          margin: EdgeInsets.zero,
          separatorIndent: 60,
          children: _recentActivities.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(28),
                    child: Center(
                      child: Text('New orders will show up here.',
                          style: ZingType.subhead(cs.onSurfaceVariant)),
                    ),
                  ),
                ]
              : _recentActivities.map(_buildActivityItem).toList(),
        ),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final amount = activity['amount']?.toString().replaceAll(r'$', 'Rs ');
    return ZingListRow(
      icon: CupertinoIcons.bag_fill,
      iconColor: ZingColors.primary,
      title: '${activity['title']}',
      subtitle: '${activity['subtitle']} · ${activity['time']}',
      trailing: amount == null
          ? null
          : Text(amount, style: ZingType.style(15, weight: FontWeight.w600, color: ZingColors.success)),
    );
  }

  Widget _buildQuickActions(bool isTablet) {
    final cs = Theme.of(context).colorScheme;
    final actions = <(String, IconData, VoidCallback)>[
      ('Add Product', CupertinoIcons.plus_app_fill, _navigateToAddProduct),
      ('Orders', CupertinoIcons.bag_fill, () => _tabController.animateTo(2)),
      ('Edit Store', CupertinoIcons.pencil, _openEditStoreDialog),
      ('Renew', CupertinoIcons.creditcard_fill, _openRenew),
    ];
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: ZingPressable(
              pressedScale: 0.94,
              onTap: actions[i].$3,
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(ZingRadius.md),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(actions[i].$2, color: cs.primary, size: 22),
                    const SizedBox(height: 5),
                    Text(actions[i].$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ZingType.style(12, weight: FontWeight.w600, color: cs.primary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductsTab(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProductsHeader(),
                const SizedBox(height: 24),
                if (_products.isEmpty)
                  _buildEmptyProductsState()
                else
                  _buildProductsGrid(isTablet),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsHeader() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Products',
              style: theme.textTheme.headlineSmall!.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_products.length} product${_products.length != 1 ? 's' : ''} total',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _navigateToAddProduct,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: cs.onPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Add Product',
                      style: TextStyle(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProductsState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.surfaceContainerHighest, cs.outline],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.inventory_2,
                color: cs.onPrimary,
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Products Yet',
              style: theme.textTheme.headlineSmall!.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start building your store by adding your first product',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium!.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _navigateToAddProduct,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, color: cs.onPrimary),
                        const SizedBox(width: 12),
                        Text(
                          'Add Your First Product',
                          style: TextStyle(
                            color: cs.onPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsGrid(bool isTablet) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isTablet ? 3 : 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        return _buildProductCard(_products[index]);
      },
    );
  }

  Widget _buildProductCard(Product product) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZingShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _navigateToEditProduct(product),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      product.imageUrl != null && product.imageUrl!.isNotEmpty
                          ? Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _buildImagePlaceholder(),
                      )
                          : _buildImagePlaceholder(),
                      // Status indicator
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: product.inStock
                                ? ZingColors.success.withValues(alpha: 0.9)
                                : cs.error.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            !product.isAvailable
                                ? 'Unavailable'
                                : product.quantity > 0
                                    ? 'In Stock (${product.quantity})'
                                    : 'Out of Stock',
                            style: TextStyle(
                              color: cs.onPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Product details
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: ZingColors.success,
                          ),
                        ),
                        if (product.rating != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: ZingColors.warning,
                                size: 14,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                product.rating!.toStringAsFixed(1),
                                style: theme.textTheme.bodySmall!.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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
    );
  }

  Widget _buildImagePlaceholder() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image,
          color: cs.onSurfaceVariant,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildOrdersTab(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildOrdersHeader(),
                const SizedBox(height: 24),
                if (_recentOrders.isEmpty)
                  _buildEmptyOrdersState()
                else
                  ..._recentOrders.take(5).map((order) => _buildOrderCard(order)),
                if (_recentOrders.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Center(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => OrderManagementPage(
                                  storeId: _currentUser!.store!.id!,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.visibility,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'View All Orders',
                                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersHeader() {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Orders',
              style: theme.textTheme.headlineSmall!.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_recentOrders.length} order${_recentOrders.length != 1 ? 's' : ''} total',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyOrdersState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.surfaceContainerHighest, cs.outline],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Icon(
                Icons.shopping_bag,
                color: cs.onPrimary,
                size: 60,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No Orders Yet',
              style: theme.textTheme.headlineSmall!.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Orders from customers will appear here',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium!.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Orders order) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final statusColor = _getStatusColor(order.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZingShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.id.substring(0, 6).toUpperCase()}',
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.userDetails?.name ?? 'Customer',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  order.status,
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${order.itemCount} item${order.itemCount > 1 ? 's' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '\$${order.totalPrice.toStringAsFixed(2)}',
                style: theme.textTheme.titleLarge!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: ZingColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final cs = Theme.of(context).colorScheme;
    switch (status.toLowerCase()) {
      case 'pending':
        return ZingColors.warning;
      case 'processing':
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

  Widget _buildFloatingActionButton() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              switch (_selectedTabIndex) {
                case 0:
                  _showQuickActionSheet();
                  break;
                case 1:
                  _navigateToAddProduct();
                  break;
                case 2:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OrderManagementPage(
                        storeId: _currentUser!.store!.id!,
                      ),
                    ),
                  );
                  break;
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedTabIndex == 0
                        ? Icons.apps
                        : _selectedTabIndex == 1
                        ? Icons.add
                        : Icons.visibility,
                    color: cs.onPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedTabIndex == 0
                        ? 'Actions'
                        : _selectedTabIndex == 1
                        ? 'Add Product'
                        : 'View All',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickActionSheet() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Quick Actions',
                style: theme.textTheme.titleLarge!.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              _buildQuickActionItem(
                icon: Icons.add_box,
                title: 'Add Product',
                subtitle: 'Create a new product',
                onTap: () {
                  Navigator.pop(context);
                  _navigateToAddProduct();
                },
              ),
              _buildQuickActionItem(
                icon: Icons.store,
                title: 'Edit Store',
                subtitle: 'Update store information',
                onTap: () {
                  Navigator.pop(context);
                  _openEditStoreDialog();
                },
              ),
              _buildQuickActionItem(
                icon: Icons.analytics,
                title: 'View Analytics',
                subtitle: 'Check your performance',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: cs.onPrimary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary.withValues(alpha: 0.1),
              cs.tertiary.withValues(alpha: 0.1),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [cs.primary, cs.primary.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
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
                'Loading Store Management...',
                style: theme.textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessDeniedScreen() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_currentUser?.store != null && !_hasAccess) {
      return Scaffold(
        body: buildRenewScreen(context, _currentUser!),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primary.withValues(alpha: 0.1),
              cs.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [cs.surfaceContainerHighest, cs.outline],
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Icon(
                      Icons.store_mall_directory,
                      color: cs.onPrimary,
                      size: 60,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Access Required',
                    style: theme.textTheme.headlineLarge!.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Create your store to start managing products and orders',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium!.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  buildAddStoreButton(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Usage for backward compatibility
class StoreManagementWidget extends StatelessWidget {
  const StoreManagementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnhancedStoreManagementWidget();
  }
}
