import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/AdminPanal/AdminStoreDetails.dart';
import 'package:zing/AdminPanal/ManageUser.dart';
import 'package:zing/AdminPanal/AddAdminScreen.dart';
import 'package:zing/AdminPanal/AdminUpdateRegitrationAmount.dart';
import 'package:zing/AdminPanal/ManageOffer.dart';
import 'package:zing/Service/ThemeProvider.dart';

class EnhancedAdminPanelDashboard extends StatefulWidget {
  const EnhancedAdminPanelDashboard({super.key});

  @override
  State<EnhancedAdminPanelDashboard> createState() => _EnhancedAdminPanelDashboardState();
}

class _EnhancedAdminPanelDashboardState extends State<EnhancedAdminPanelDashboard>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  final List<NavigationItem> _navigationItems = [
    NavigationItem('Dashboard', Icons.dashboard_rounded, 0),
    NavigationItem('Stores', Icons.store_rounded, 1),
    NavigationItem('Users', Icons.people_rounded, 2),
    NavigationItem('Admins', Icons.admin_panel_settings_rounded, 3),
    NavigationItem('Offers', Icons.local_offer_rounded, 4),
    NavigationItem('Advertisements', Icons.campaign_rounded, 5),
    NavigationItem('Settings', Icons.settings_rounded, 6),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-0.3, 0),
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

    _startAnimations();
  }

  void _startAnimations() async {
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _slideController.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    _scaleController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final Size size = MediaQuery.of(context).size;
    final storeProvider = Provider.of<StoreProvider>(context);
    final customUserProvider = Provider.of<CustomUserProvider>(context);
    final bool isSmallScreen = size.width < 1024;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: isSmallScreen ? _buildMobileAppBar(context) : null,
      drawer: isSmallScreen ? _buildMobileDrawer(context) : null,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: Row(
            children: [
              if (!isSmallScreen) _buildDesktopSidebar(context),
              Expanded(
                child: _buildMainContent(storeProvider, customUserProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppBar(
      elevation: 0,
      backgroundColor: cs.surface,
      surfaceTintColor: cs.surface,
      title: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'Z',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Zing Admin',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        _buildNotificationButton(),
        const SizedBox(width: 8),
        _buildProfileButton(),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildDesktopSidebar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: _isSidebarExpanded ? 280 : 80,
        decoration: BoxDecoration(
          color: cs.surface,
          boxShadow: ZingShadows.soft,
        ),
        child: Column(
          children: [
            _buildSidebarHeader(),
            const SizedBox(height: 32),
            Expanded(
              child: _buildNavigationList(),
            ),
            _buildSidebarFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarHeader() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
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
            child: Center(
              child: Text(
                'Z',
                style: TextStyle(
                  color: cs.onPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_isSidebarExpanded) ...[
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Zing Admin',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () {
                setState(() {
                  _isSidebarExpanded = !_isSidebarExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  _isSidebarExpanded ? Icons.chevron_left : Icons.chevron_right,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationList() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _navigationItems.length,
      itemBuilder: (context, index) {
        final item = _navigationItems[index];
        final isSelected = _selectedIndex == item.index;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _selectedIndex = item.index;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                    colors: [cs.primary, cs.secondary],
                  )
                      : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.icon,
                      color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                      size: 20,
                    ),
                    if (_isSidebarExpanded) ...[
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            color: isSelected ? cs.onPrimary : cs.onSurface,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebarFooter() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            _showLogoutDialog();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: cs.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  color: cs.error,
                  size: 20,
                ),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Logout',
                    style: TextStyle(
                      color: cs.error,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Drawer(
      backgroundColor: cs.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.secondary],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'Z',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Zing Admin Panel',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Manage your application',
                        style: TextStyle(
                          color: cs.onPrimary.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _navigationItems.length,
                itemBuilder: (context, index) {
                  final item = _navigationItems[index];
                  final isSelected = _selectedIndex == item.index;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Icon(
                        item.icon,
                        color: isSelected ? cs.primary : cs.onSurfaceVariant,
                      ),
                      title: Text(
                        item.title,
                        style: TextStyle(
                          color: isSelected ? cs.primary : cs.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: cs.primary.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        setState(() {
                          _selectedIndex = item.index;
                        });
                        Navigator.pop(context);
                      },
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              child: ListTile(
                leading: Icon(Icons.logout_rounded, color: cs.error),
                title: Text(
                  'Logout',
                  style: TextStyle(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: cs.error.withValues(alpha: 0.1),
                onTap: () {
                  Navigator.pop(context);
                  _showLogoutDialog();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent(StoreProvider storeProvider, CustomUserProvider userProvider) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: SizedBox(
        height: double.infinity,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 32),
                    _buildStatsSection(storeProvider, userProvider),
                    const SizedBox(height: 40),
                    _buildQuickActions(),
                    const SizedBox(height: 40),
                    _buildDataSections(storeProvider, userProvider),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, Admin! 👋',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width < 600 ? 24 : 32,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
                style: TextStyle(
                  fontSize: 16,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (MediaQuery.of(context).size.width > 600) ...[
          _buildSearchBar(),
          const SizedBox(width: 16),
          _buildNotificationButton(),
          const SizedBox(width: 12),
          _buildProfileButton(),
        ],
      ],
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: 300,
      height: 48,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(color: cs.onSurfaceVariant),
          prefixIcon: Icon(Icons.search, color: cs.onSurfaceVariant),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: cs.onSurfaceVariant),
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
            },
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
      ),
    );
  }

  Widget _buildNotificationButton() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.notifications_rounded, color: cs.onSurfaceVariant),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: cs.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileButton() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.secondary],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {},
          child: Center(
            child: Text(
              'A',
              style: TextStyle(
                color: cs.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsSection(StoreProvider storeProvider, CustomUserProvider userProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final stats = [
      StatCard(
        'Total Stores',
        storeProvider.stores.length.toString(),
        Icons.store_rounded,
        cs.primary,
        null,
      ),
      StatCard(
        'Total Users',
        userProvider.users.length.toString(),
        Icons.people_rounded,
        ZingColors.success,
        null,
      ),
      StatCard(
        'Active Admins',
        userProvider.users.where((user) => user.role == 'Admin').length.toString(),
        Icons.admin_panel_settings_rounded,
        cs.error,
        null,
      ),
      StatCard(
        'Store Owners',
        userProvider.users.where((user) => user.role == 'Owner').length.toString(),
        Icons.storefront_rounded,
        ZingColors.warning,
        null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;

        if (isWide) {
          return Row(
            children: stats.map((stat) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: _buildStatCard(stat),
              ),
            )).toList(),
          );
        } else {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard(stats[0])),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard(stats[1])),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildStatCard(stats[2])),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard(stats[3])),
                ],
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildStatCard(StatCard stat) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: stat.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  stat.icon,
                  color: stat.color,
                  size: 24,
                ),
              ),
              if (stat.change != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: ZingColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    stat.change!,
                    style: const TextStyle(
                      color: ZingColors.success,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.title,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final actions = [
      QuickAction(
        'Registration Settings',
        'Manage registration fees',
        Icons.payments_rounded,
        cs.primary,
            () => Navigator.push(context, MaterialPageRoute(
          builder: (context) => EnhancedAdminUpdateRegistrationAmountScreen(),
        )),
      ),
      QuickAction(
        'Manage Users',
        'View and manage accounts',
        Icons.people_rounded,
        ZingColors.success,
            () => Navigator.push(context, MaterialPageRoute(
          builder: (context) => ManageUsersPage(),
        )),
      ),
      QuickAction(
        'Add Admin',
        'Create new admin accounts',
        Icons.admin_panel_settings_rounded,
        cs.error,
            () => Navigator.push(context, MaterialPageRoute(
          builder: (context) => AddAdminScreen(),
        )),
      ),
      QuickAction(
        'Manage Offers',
        'Create special offers',
        Icons.local_offer_rounded,
        ZingColors.warning,
            () => Navigator.push(context, MaterialPageRoute(
          builder: (context) => ManageOfferPage(),
        )),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 800;

            if (isWide) {
              return Row(
                children: actions.map((action) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: _buildQuickActionCard(action),
                  ),
                )).toList(),
              );
            } else {
              return Column(
                children: actions.map((action) => Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: _buildQuickActionCard(action),
                )).toList(),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(QuickAction action) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: action.onTap,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    action.icon,
                    color: action.color,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  action.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Text(
                      'Manage',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: action.color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: action.color,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDataSections(StoreProvider storeProvider, CustomUserProvider userProvider) {
    return Column(
      children: [
        _buildRecentStores(storeProvider),
        const SizedBox(height: 40),
        _buildRecentAdmins(userProvider),
      ],
    );
  }

  Widget _buildRecentStores(StoreProvider storeProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Stores',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (storeProvider.isLoading)
          _buildLoadingState()
        else if (storeProvider.stores.isEmpty)
          _buildEmptyState('No stores found', 'Create your first store')
        else
          ...storeProvider.stores.take(3).map((store) => _buildStoreCard(store)),
      ],
    );
  }

  Widget _buildRecentAdmins(CustomUserProvider userProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final admins = userProvider.users.where((user) => user.role == 'Admin').take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Admins',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            TextButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (userProvider.isLoading)
          _buildLoadingState()
        else if (admins.isEmpty)
          _buildEmptyState('No admins found', 'Add your first admin')
        else
          ...admins.map((admin) => _buildAdminCard(admin)),
      ],
    );
  }

  Widget _buildStoreCard(Store store) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AdminStoreDetailScreen(store: store),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getStoreColor(store.name),
                        _getStoreColor(store.name).withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.store_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Category: ${store.category}',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (MediaQuery.of(context).size.width > 600) ...[
                  _buildStoreMetric('Products', store.products.length.toString()),
                  const SizedBox(width: 20),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ZingColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ZingColors.success,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: cs.onSurfaceVariant,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoreMetric(String label, String value) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildAdminCard(CustomUser admin) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.secondary],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  admin.name.isNotEmpty ? admin.name[0].toUpperCase() : 'A',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    admin.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    admin.email,
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (MediaQuery.of(context).size.width > 600)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Last Active',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '2 hours ago',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ZingColors.success,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (value) {},
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_rounded, size: 18, color: cs.primary),
                      const SizedBox(width: 12),
                      const Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded, size: 18, color: cs.error),
                      const SizedBox(width: 12),
                      const Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading...',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      height: 200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.inbox_rounded,
              size: 32,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.logout_rounded, color: cs.error),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Handle logout
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Color _getStoreColor(String name) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final colors = [
      cs.primary,
      ZingColors.success,
      cs.error,
      ZingColors.warning,
      cs.secondary,
    ];
    return colors[name.hashCode % colors.length];
  }
}

// Data classes
class NavigationItem {
  final String title;
  final IconData icon;
  final int index;

  NavigationItem(this.title, this.icon, this.index);
}

class StatCard {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? change;

  StatCard(this.title, this.value, this.icon, this.color, this.change);
}

class QuickAction {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  QuickAction(this.title, this.description, this.icon, this.color, this.onTap);
}

// Extension for Store model
extension StoreExtension on Store {
  bool get isActive => true;
}

// Usage for backward compatibility
class AdminPanelDashboard extends StatelessWidget {
  const AdminPanelDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const EnhancedAdminPanelDashboard();
  }
}
