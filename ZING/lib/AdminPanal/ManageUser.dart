import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zing/AdminPanal/UserDetails.dart';
import '../Modal/CoustomUser.dart';
import '../Service/CoustomUserProvider.dart';
import '../Service/ThemeProvider.dart';

class ManageUsersPage extends StatefulWidget {
  @override
  _ManageUsersPageState createState() => _ManageUsersPageState();
}

class _ManageUsersPageConstants {
  static const double borderRadius = 16.0;
  static const Duration searchDebounceTime = Duration(milliseconds: 300);
  static const String title = 'Manage Users';
  static const double elevation = 2.0;
  static const double spacing = 16.0;
}

class _ManageUsersPageState extends State<ManageUsersPage> with TickerProviderStateMixin {
  String searchQuery = '';
  Timer? _debounce;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTopButton = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentTabIndex = 0;

  // Animation controllers
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChange);
    _scrollController.addListener(_onScroll);

    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut)
    );

    _animationController.forward();

    // Debug Firestore data after a short delay
    Future.delayed(Duration(seconds: 2), () {
      _debugUserData();
    });
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  void _onScroll() {
    setState(() {
      _showBackToTopButton = _scrollController.offset >= 200;
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // ADDED: Debug method to understand user data
  void _debugUserData() {
    final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
    final users = userProvider.users ?? [];

    print("=== DEBUGGING USER DATA IN UI ===");
    print("Total users loaded: ${users.length}");

    final roleCount = <String, int>{};
    users.forEach((user) {
      print("User: ${user.name}, Role: '${user.role}', Role Type: ${user.role?.runtimeType}");
      final role = user.role ?? 'null';
      roleCount[role] = (roleCount[role] ?? 0) + 1;
    });

    print("Role distribution: $roleCount");
    print("=== END UI DEBUG ===");

    // Also trigger provider debug
    userProvider.debugFirestoreData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userProvider = Provider.of<CustomUserProvider>(context);
    final users = userProvider.users ?? [];

    // FIXED: Filter users with case-insensitive search and better null handling
    final filteredUsers = users.where((user) {
      final name = user.name?.toLowerCase() ?? '';
      final email = user.email?.toLowerCase() ?? '';
      final query = searchQuery.toLowerCase();
      return name.contains(query) || email.contains(query);
    }).toList();

    // FIXED: Case-insensitive role filtering with better debugging
    final admins = filteredUsers.where((user) {
      final role = user.role?.toLowerCase() ?? '';
      final isAdmin = role == 'admin';
      if (isAdmin) {
        print("Found admin: ${user.name} with role: '${user.role}'");
      }
      return isAdmin;
    }).toList();

    final owners = filteredUsers.where((user) {
      final role = user.role?.toLowerCase() ?? '';
      final isOwner = role == 'owner';
      if (isOwner) {
        print("Found owner: ${user.name} with role: '${user.role}'");
      }
      return isOwner;
    }).toList();

    final regularUsers = filteredUsers.where((user) {
      final role = user.role?.toLowerCase() ?? '';
      final isUser = role == 'user';
      if (isUser) {
        print("Found user: ${user.name} with role: '${user.role}'");
      }
      return isUser;
    }).toList();

    // Debug role counts
    print("Filtered counts - Admins: ${admins.length}, Owners: ${owners.length}, Users: ${regularUsers.length}");

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: cs.surface,
      appBar: _buildAppBar(userProvider),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: userProvider.isLoading
              ? _buildLoadingIndicator()
              : _buildMainContent(admins, owners, regularUsers, userProvider, users),
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar(CustomUserProvider userProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppBar(
      elevation: 0,
      title: Text(
        _ManageUsersPageConstants.title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
          letterSpacing: 0.5,
        ),
      ),
      centerTitle: true,
      actions: [
        // ADDED: Debug button
        IconButton(
          icon: Icon(Icons.bug_report),
          tooltip: 'Debug Users',
          onPressed: _debugUserData,
        ),
        IconButton(
          icon: Icon(Icons.refresh),
          tooltip: 'Refresh Users',
          onPressed: () {
            print("Refreshing users...");
            userProvider.fetchUsers();
          },
        ),
      ],
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(48),
        child: TabBar(
          controller: _tabController,
          indicatorWeight: 3,
          tabs: [
            Tab(
              icon: Icon(Icons.admin_panel_settings_outlined),
              text: 'Admins',
            ),
            Tab(
              icon: Icon(Icons.store_outlined),
              text: 'Owners',
            ),
            Tab(
              icon: Icon(Icons.person_outline),
              text: 'Users',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SpinKitFadingCircle(
            color: cs.primary,
            size: 60.0,
          ),
          SizedBox(height: 16),
          Text(
            'Loading Users...',
            style: TextStyle(
              fontSize: 18,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
      List<CustomUser> admins,
      List<CustomUser> owners,
      List<CustomUser> regularUsers,
      CustomUserProvider userProvider,
      List<CustomUser> allUsers,
      ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      children: [
        _buildSearchBar(),
        // ADDED: Debug info bar
        if (allUsers.isNotEmpty)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: cs.primary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: cs.primary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total: ${allUsers.length} | Admins: ${admins.length} | Owners: ${owners.length} | Users: ${regularUsers.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUserList(admins, userProvider, 'Admins'),
              _buildUserList(owners, userProvider, 'Owners'),
              _buildUserList(regularUsers, userProvider, 'Users'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(_ManageUsersPageConstants.borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search,
            color: cs.onSurfaceVariant,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users by name or email...',
                hintStyle: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 16),
              ),
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurface,
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () {
                setState(() {
                  searchQuery = '';
                });
              },
              child: Icon(
                Icons.clear,
                color: cs.onSurfaceVariant,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<CustomUser> users, CustomUserProvider userProvider, String title) {
    print("Building user list for $title with ${users.length} users");

    if (users.isEmpty) {
      return _buildEmptyState(title);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) => _buildUserCard(users[index], userProvider),
    );
  }

  Widget _buildEmptyState(String userType) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final List<Map<String, dynamic>> emptyStateData = [
      {
        'icon': Icons.admin_panel_settings_outlined,
        'message': 'No Administrators Found',
        'subMessage': 'Add new admins to help manage your platform',
      },
      {
        'icon': Icons.store_outlined,
        'message': 'No Store Owners Found',
        'subMessage': 'Invite store owners to join your platform',
      },
      {
        'icon': Icons.person_outline,
        'message': 'No Regular Users Found',
        'subMessage': 'Users will appear here once they register',
      },
    ];

    int dataIndex = 0;
    switch (userType) {
      case 'Admins':
        dataIndex = 0;
        break;
      case 'Owners':
        dataIndex = 1;
        break;
      case 'Users':
        dataIndex = 2;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            emptyStateData[dataIndex]['icon'],
            size: 80,
            color: cs.onSurfaceVariant,
          ),
          SizedBox(height: 24),
          Text(
            emptyStateData[dataIndex]['message'],
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              searchQuery.isNotEmpty
                  ? 'Try adjusting your search criteria'
                  : emptyStateData[dataIndex]['subMessage'],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          if (searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    searchQuery = '';
                  });
                },
                icon: Icon(Icons.clear),
                label: Text('Clear Search'),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserCard(CustomUser user, CustomUserProvider userProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userName = user.name ?? 'Unknown User';
    final userEmail = user.email ?? 'No email provided';
    final userRole = user.role ?? 'No role assigned';

    final Color avatarColor = _getColorForRole(userRole);
    final Color roleChipColor = _getColorForRole(userRole);

    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _viewUserDetails(user, context),
          borderRadius: BorderRadius.circular(_ManageUsersPageConstants.borderRadius),
          splashColor: cs.primary.withOpacity(0.1),
          highlightColor: cs.primary.withOpacity(0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User header
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surface,
                ),
                child: Row(
                  children: [
                    _buildUserAvatar(userName, avatarColor),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            userName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: cs.onSurface,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            userEmail,
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 8),
                          _buildRoleChip(userRole, roleChipColor),
                          // ADDED: Debug info for individual user
                          if (userRole.isEmpty || userRole == 'No role assigned')
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'DEBUG: Role is null or empty',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: cs.error,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Divider
              Divider(height: 1, thickness: 1, color: cs.outlineVariant),

              // Actions section
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store access section (for Admin and Owner)
                    if (user.role?.toLowerCase() == 'owner' || user.role?.toLowerCase() == 'admin')
                      _buildStoreAccessSection(user, userProvider),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Edit button
                        OutlinedButton.icon(
                          onPressed: () => _viewUserDetails(user, context),
                          icon: Icon(Icons.edit_outlined, size: 18),
                          label: Text('EDIT'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.primary,
                            side: BorderSide(color: cs.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                        SizedBox(width: 8),
                        // Delete button
                        OutlinedButton.icon(
                          onPressed: () => _deleteUser(user, userProvider, context),
                          icon: Icon(Icons.delete_outline, size: 18),
                          label: Text('DELETE'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: cs.error,
                            side: BorderSide(color: cs.error),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
    );
  }

  Widget _buildUserAvatar(String userName, Color backgroundColor) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Hero(
      tag: 'avatar_${userName}',
      child: Material(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: CircleBorder(),
        child: CircleAvatar(
          backgroundColor: backgroundColor,
          radius: 28,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : '?',
            style: TextStyle(
              color: cs.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, Color chipColor) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: chipColor.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getIconForRole(role),
            size: 14,
            color: chipColor,
          ),
          SizedBox(width: 6),
          Text(
            role,
            style: TextStyle(
              color: chipColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreAccessSection(CustomUser user, CustomUserProvider userProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.store,
              size: 16,
              color: cs.onSurfaceVariant,
            ),
            SizedBox(width: 8),
            Text(
              'Store Access',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: cs.onSurface,
              ),
            ),
            Spacer(),
            Switch.adaptive(
              value: user.storeAccess,
              onChanged: (value) => _toggleStoreAccess(user, value, userProvider, context),
            ),
          ],
        ),
        Divider(height: 24, thickness: 1, color: cs.outlineVariant),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return _showBackToTopButton
        ? FloatingActionButton(
      onPressed: _scrollToTop,
      child: Icon(Icons.arrow_upward),
      tooltip: 'Back to Top',
      elevation: 4,
    )
        : null;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(_ManageUsersPageConstants.searchDebounceTime, () {
      setState(() {
        searchQuery = query;
      });
    });
  }

  Future<void> _toggleStoreAccess(
      CustomUser user,
      bool value,
      CustomUserProvider userProvider,
      BuildContext context,
      ) async {
    final scaffold = ScaffoldMessenger.of(context);
    try {
      _showProgressSnackBar(scaffold, 'Updating store access...');

      await userProvider.updatePaymentStatusAndStoreAccess(user, value);
      setState(() {
        user.storeAccess = value;
      });

      scaffold.clearSnackBars();
      _showSuccessSnackBar(scaffold, 'Store access updated successfully');
    } catch (e) {
      scaffold.clearSnackBars();
      _showErrorSnackBar(scaffold, 'Failed to update store access: $e');
    }
  }

  void _viewUserDetails(CustomUser user, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserDetailsPage(user: user),
      ),
    );
  }

  Future<void> _deleteUser(
      CustomUser user,
      CustomUserProvider userProvider,
      BuildContext context,
      ) async {
    final confirm = await _showDeleteConfirmation(context, user);
    if (confirm) {
      final scaffold = ScaffoldMessenger.of(context);
      bool isOwner = user.role?.toLowerCase() == 'owner';
      String? storeId = isOwner ? user.store?.id : null;

      try {
        _showProgressSnackBar(scaffold, 'Deleting user...');

        await userProvider.deleteUser(user.id, isOwner: isOwner, storeId: storeId);

        scaffold.clearSnackBars();
        _showSuccessSnackBar(scaffold, 'User deleted successfully');
      } catch (e) {
        scaffold.clearSnackBars();
        _showErrorSnackBar(scaffold, 'Failed to delete user: $e');
      }
    }
  }

  Future<bool> _showDeleteConfirmation(BuildContext context, CustomUser user) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userName = user.name ?? 'this user';

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_ManageUsersPageConstants.borderRadius),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: cs.error),
            SizedBox(width: 12),
            Text('Delete User'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete $userName?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'This action cannot be undone and all associated data will be permanently removed.',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
              ),
            ),
            if (user.role?.toLowerCase() == 'owner')
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: cs.error.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: cs.error,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: This will also delete all store data associated with this owner.',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL'),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: Icon(Icons.delete_outline, size: 18),
            label: Text('DELETE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showProgressSnackBar(ScaffoldMessengerState scaffold, String message) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    scaffold.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            SizedBox(width: 16),
            Text(message),
          ],
        ),
        backgroundColor: cs.onSurface,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(ScaffoldMessengerState scaffold, String message) {
    scaffold.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.white),
            SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: ZingColors.success,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(ScaffoldMessengerState scaffold, String message) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    scaffold.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: cs.error,
        behavior: SnackBarBehavior.fixed,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        duration: Duration(seconds: 4),
      ),
    );
  }

  // Helper methods for styling
  Color _getColorForRole(String role) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    switch (role.toLowerCase()) {
      case 'admin':
        return cs.primary;
      case 'owner':
        return cs.secondary;
      default:
        return ZingColors.success;
    }
  }

  IconData _getIconForRole(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Icons.admin_panel_settings;
      case 'owner':
        return Icons.store;
      default:
        return Icons.person;
    }
  }
}
