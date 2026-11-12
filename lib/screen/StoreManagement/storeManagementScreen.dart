import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';

import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/StoreManagementWidgets/BuildProductGride.dart';
import 'package:zing/Widgets/StoreManagementWidgets/OrederWidets.dart';
import '../../Modal/CoustomUser.dart';
import '../../Service/CoustomUserProvider.dart';
import '../../Service/StoreProvider.dart';
import '../../Widgets/StoreManagementWidgets/BuildRenewScreen.dart';
import '../../Widgets/StoreManagementWidgets/BuildStoreHeader.dart';
import '../../Widgets/StoreManagementWidgets/buildAddProductButton.dart';
import '../../Widgets/StoreManagementWidgets/buildAddStoreButton.dart';
import 'EditStoreScreen.dart';
import 'EditProduct.dart';

class EnhancedStoreManagementWidget extends StatefulWidget {
  const EnhancedStoreManagementWidget({Key? key}) : super(key: key);

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

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
      final paymentSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('payments')
          .orderBy('paymentDate', descending: true)
          .limit(1)
          .get();

      if (paymentSnapshot.docs.isNotEmpty) {
        final paymentData = paymentSnapshot.docs.first.data();
        final paymentDate = (paymentData['paymentDate'] as Timestamp).toDate();
        _daysLeft = 30 - DateTime.now().difference(paymentDate).inDays;

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
      final productSnapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('products')
          .get();

      if (!mounted) return;

      final products = productSnapshot.docs.map((doc) {
        final data = doc.data();
        return Product(
          id: doc.id,
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          price: (data['price'] ?? 0).toDouble(),
          rating: (data['rating'] ?? 0).toDouble(),
          imageUrl: data['imageUrl'] ?? '',
          isAvailable: data['isAvailable'] ?? true,
          discount: data['discount']?.toDouble(),
        );
      }).toList();

      setState(() {
        _products = products;
      });
    } catch (e) {
      debugPrint("Error fetching products: $e");
    }
  }

  Future<void> _fetchRecentOrders(String storeId) async {
    try {
      final orderSnapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('orders')
          .orderBy('placedAt', descending: true)
          .limit(10)
          .get();

      if (!mounted) return;

      final orders = orderSnapshot.docs.map((doc) {
        return Orders.fromDocument(doc);
      }).toList();

      setState(() {
        _recentOrders = orders;
        _totalOrders = orders.length;
        _totalRevenue = orders.fold(0, (prev, order) => prev + order.totalPrice);
      });
    } catch (e) {
      debugPrint("Error fetching orders: $e");
    }
  }

  Future<void> _fetchCustomerCount(String storeId) async {
    try {
      final orderSnapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('orders')
          .get();

      final uniqueCustomers = <String>{};
      for (var doc in orderSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        if (userId != null) {
          uniqueCustomers.add(userId);
        }
      }

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

      final orderSnapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('orders')
          .where('placedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(lastWeek))
          .orderBy('placedAt', descending: false)
          .get();

      final Map<String, double> salesByDay = {
        'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0,
      };

      for (var doc in orderSnapshot.docs) {
        final data = doc.data();
        final placedAt = (data['placedAt'] as Timestamp).toDate();
        final dayName = DateFormat('E').format(placedAt).substring(0, 3);
        final price = (data['totalPrice'] as num).toDouble();

        salesByDay[dayName] = (salesByDay[dayName] ?? 0) + price;
      }

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
      final orderSnapshot = await _firestore
          .collection('stores')
          .doc(storeId)
          .collection('orders')
          .orderBy('placedAt', descending: true)
          .limit(3)
          .get();

      for (var doc in orderSnapshot.docs) {
        final data = doc.data();
        final orderTime = (data['placedAt'] as Timestamp).toDate();
        final timeDiff = DateTime.now().difference(orderTime);

        String timeAgo;
        if (timeDiff.inMinutes < 60) {
          timeAgo = '${timeDiff.inMinutes} minutes ago';
        } else if (timeDiff.inHours < 24) {
          timeAgo = '${timeDiff.inHours} hours ago';
        } else {
          timeAgo = '${timeDiff.inDays} days ago';
        }

        activities.add({
          'type': 'order',
          'title': 'New order #${doc.id.substring(0, 4)}',
          'subtitle': 'Order of \$${data['totalPrice']} placed',
          'time': timeAgo,
          'amount': '\$${(data['totalPrice'] as num).toStringAsFixed(2)}',
        });
      }

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

  void _navigateToAddProduct() {
    if (_currentUser?.store?.id != null) {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              EditProductScreen(storeId: _currentUser!.store!.id!),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

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
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              EditProductScreen(
                product: product,
                storeId: _currentUser!.store!.id!,
              ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    if (_isLoading) {
      return _buildLoadingScreen();
    }

    if (_currentUser == null || !_currentUser!.storeAccess!) {
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

  Widget _buildAppBar(bool isTablet) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cs.primary,
              cs.primary.withOpacity(0.8),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Store name and edit button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _currentUser!.store!.name,
                        style: theme.textTheme.headlineLarge!.copyWith(
                          fontSize: isTablet ? 32 : 26,
                          fontWeight: FontWeight.w800,
                          color: cs.onPrimary,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: cs.onPrimary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.edit, color: cs.onPrimary),
                        onPressed: _openEditStoreDialog,
                        tooltip: 'Edit Store Details',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Store status and subscription info
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.onPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: cs.onPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Active',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _daysLeft <= 7
                              ? ZingColors.warning.withOpacity(0.2)
                              : cs.onPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: cs.onPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$_daysLeft days left',
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: cs.onPrimary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.category,
                              size: 12,
                              color: cs.onPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _currentUser!.store!.category,
                              style: theme.textTheme.bodySmall!.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ZingShadows.soft,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: TabBar(
            controller: _tabController,
            labelColor: cs.onPrimary,
            unselectedLabelColor: cs.onSurfaceVariant,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorPadding: const EdgeInsets.all(4),
            labelStyle: theme.textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            unselectedLabelStyle: theme.textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Products'),
              Tab(text: 'Orders'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardTab(bool isTablet) {
    return SlideTransition(
      position: _slideAnimation,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_daysLeft <= 7 && _daysLeft > 0) _buildWarningBanner(),
                _buildStatsCards(isTablet),
                const SizedBox(height: 32),
                _buildSalesChart(),
                const SizedBox(height: 32),
                _buildRecentActivity(),
                const SizedBox(height: 32),
                _buildQuickActions(isTablet),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [ZingColors.warning.withOpacity(0.1), cs.error.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: ZingColors.warning.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ZingColors.warning.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.warning_rounded,
              color: ZingColors.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription Expiring Soon',
                  style: theme.textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: ZingColors.warning,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your store access expires in $_daysLeft days. Renew to continue.',
                  style: theme.textTheme.bodyMedium!.copyWith(
                    color: ZingColors.warning,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [ZingColors.warning, cs.error],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  // Navigate to renewal
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    'Renew',
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(bool isTablet) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Store Overview',
            style: theme.textTheme.titleLarge!.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          isTablet
              ? Row(
            children: [
              Expanded(child: _buildStatCard('Products', '${_products.length}', Icons.inventory_2, cs.primary)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Orders', '$_totalOrders', Icons.shopping_bag, ZingColors.warning)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Customers', '$_totalCustomers', Icons.people, ZingColors.success)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Revenue', '\$${_totalRevenue.toStringAsFixed(0)}', Icons.trending_up, cs.tertiary)),
            ],
          )
              : Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard('Products', '${_products.length}', Icons.inventory_2, cs.primary)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Orders', '$_totalOrders', Icons.shopping_bag, ZingColors.warning)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard('Customers', '$_totalCustomers', Icons.people, ZingColors.success)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('Revenue', '\$${_totalRevenue.toStringAsFixed(0)}', Icons.trending_up, cs.tertiary)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              Icon(Icons.more_horiz, color: cs.onSurfaceVariant, size: 20),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            value,
            style: theme.textTheme.headlineLarge!.copyWith(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesChart() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
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
              Text(
                'Sales Analytics',
                style: theme.textTheme.titleLarge!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'This week',
                  style: theme.textTheme.bodySmall!.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: _buildCustomChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomChart() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_salesData.isEmpty) {
      return Center(
        child: Text(
          "No sales data available",
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final maxValue = _salesData.values.isNotEmpty
        ? _salesData.values.reduce((a, b) => a > b ? a : b)
        : 100;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: _salesData.entries.map((entry) {
        final percentage = maxValue > 0 ? entry.value / maxValue : 0;
        final isHighest = maxValue > 0 && entry.value == maxValue;

        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 32,
              height: (160 * percentage).toDouble(),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isHighest
                      ? [cs.primary, cs.primary.withOpacity(0.8)]
                      : [cs.outline, cs.surfaceContainerHighest],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.key,
              style: theme.textTheme.bodySmall!.copyWith(
                fontWeight: isHighest ? FontWeight.w600 : FontWeight.w500,
                color: isHighest ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildRecentActivity() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
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
              Text(
                'Recent Activity',
                style: theme.textTheme.titleLarge!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(2); // Switch to Orders tab
                },
                child: Text(
                  'View All',
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_recentActivities.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.timeline,
                      size: 48,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No recent activities',
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recentActivities.map((activity) => _buildActivityItem(activity)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shopping_bag,
              color: cs.onPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'],
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity['subtitle'],
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  activity['time'],
                  style: theme.textTheme.labelSmall!.copyWith(
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (activity['amount'] != null)
            Text(
              activity['amount'],
              style: theme.textTheme.titleSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: ZingColors.success,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isTablet) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final actions = [
      {
        'title': 'Add Product',
        'icon': Icons.add_box,
        'color': cs.primary,
        'onTap': _navigateToAddProduct,
      },
      {
        'title': 'View Orders',
        'icon': Icons.shopping_bag,
        'color': ZingColors.warning,
        'onTap': () => _tabController.animateTo(2),
      },
      {
        'title': 'Edit Store',
        'icon': Icons.store,
        'color': cs.tertiary,
        'onTap': _openEditStoreDialog,
      },
      {
        'title': 'Analytics',
        'icon': Icons.analytics,
        'color': ZingColors.success,
        'onTap': () {},
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge!.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isTablet ? 4 : 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final action = actions[index];
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
                  onTap: action['onTap'] as VoidCallback,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                (action['color'] as Color).withOpacity(0.1),
                                (action['color'] as Color).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            action['icon'] as IconData,
                            color: action['color'] as Color,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          action['title'] as String,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall!.copyWith(
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
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
              colors: [cs.primary, cs.primary.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.3),
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
                  colors: [cs.primary, cs.primary.withOpacity(0.8)],
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
                            color: product.isAvailable
                                ? ZingColors.success.withOpacity(0.9)
                                : cs.error.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.isAvailable ? 'In Stock' : 'Out of Stock',
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
                              Icon(
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
    final cs = theme.colorScheme;

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
                      color: statusColor.withOpacity(0.1),
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
                  color: statusColor.withOpacity(0.1),
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
                '${order.products.length} item${order.products.length > 1 ? 's' : ''}',
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
            colors: [cs.primary, cs.primary.withOpacity(0.8)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withOpacity(0.4),
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
                      colors: [cs.primary, cs.primary.withOpacity(0.8)],
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
              cs.primary.withOpacity(0.1),
              cs.tertiary.withOpacity(0.1),
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
                    colors: [cs.primary, cs.primary.withOpacity(0.8)],
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
              cs.primary.withOpacity(0.1),
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
  const StoreManagementWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const EnhancedStoreManagementWidget();
  }
}
