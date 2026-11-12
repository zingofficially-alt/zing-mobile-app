import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:zing/AdminPanal/AdminPanalDashBoard.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/screen/StoreManagement/storeManagementScreen.dart';
import 'package:zing/screen/UserScreens/EditeUser.dart';
import 'package:zing/screen/UserScreens/FavouriteStoreScreen.dart';
import 'OrderHistoryPage.dart';
import 'SettingPage.dart';

class UserProfilePage extends StatefulWidget {
  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<CustomUserProvider>(context);
    final user = userProvider.user;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: cs.surface,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: cs.surface,
        body: userProvider.isLoading
            ? _buildLoadingState()
            : user != null
            ? _buildProfileContent(context, user, screenHeight, screenWidth)
            : _buildErrorState(),
      ),
    );
  }

  // Enhanced loading state with animation
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
            'Loading profile...',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Error state with retry option
  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_circle_outlined,
            size: 100,
            color: cs.onSurfaceVariant,
          ),
          const SizedBox(height: 24),
          Text(
            'Profile Unavailable',
            style: theme.textTheme.headlineLarge?.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'We couldn\'t load your profile information. Please try again.',
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
              // Refresh user data
              Provider.of<CustomUserProvider>(context, listen: false).fetchUserDetails();
              HapticFeedback.mediumImpact();
            },
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              'Retry',
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

  // Main profile content
  Widget _buildProfileContent(BuildContext context, CustomUser user, double screenHeight, double screenWidth) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Stack(
      children: [
        // Background gradient for profile header
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: screenHeight * 0.4,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.primary,
                  Color.lerp(cs.primary, cs.tertiary, 0.5)!,
                ],
              ),
            ),
          ),
        ),

        // Main scrollable content
        CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Profile header with avatar and basic info
            SliverToBoxAdapter(
              child: _buildEnhancedProfileHeader(context, user, screenHeight),
            ),

            // Main content sections
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Text(
                  'Account',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),

            // Profile info card
            SliverToBoxAdapter(
              child: _buildEnhancedProfileInfoCard(user, screenWidth),
            ),

            // Options header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Text(
                  'Options',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),

            // Profile options
            SliverToBoxAdapter(
              child: _buildEnhancedProfileOptions(context, screenWidth, user),
            ),

            // Bottom action buttons
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 100),
                child: _buildEnhancedActionButtons(context, screenWidth),
              ),
            ),
          ],
        ),

        // Back button (placed here instead of app bar)
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, top: 8),
            child: Material(
              color: cs.onPrimary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  Navigator.pop(context);
                  HapticFeedback.lightImpact();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: cs.onPrimary,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Edit button at top right
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 16, top: 8),
              child: Material(
                color: cs.onPrimary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfilePage(),
                      ),
                    );
                    HapticFeedback.lightImpact();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.edit_outlined,
                      color: cs.onPrimary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Enhanced profile header with parallax effect
  Widget _buildEnhancedProfileHeader(BuildContext context, CustomUser user, double screenHeight) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16),
      height: screenHeight * 0.42,
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.onPrimary.withOpacity(0.1),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.onPrimary.withOpacity(0.05),
              ),
            ),
          ),

          // Content
          Center(
            child: Column(
              children: [
                const SizedBox(height: 15), // Extra space since we removed the app bar

                // Profile image with animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: child,
                    );
                  },
                  child: Hero(
                    tag: 'profile-image',
                    child: Stack(
                      children: [
                        Container(
                          height: 120,
                          width: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: cs.onPrimary, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: user.profileImageUrl.isNotEmpty
                                ? CachedNetworkImage(
                              imageUrl: user.profileImageUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: cs.surfaceContainerHighest,
                                child: Icon(
                                  Icons.person,
                                  size: 60,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: cs.surfaceContainerHighest,
                                child: Icon(
                                  Icons.error_outline,
                                  size: 40,
                                  color: cs.error,
                                ),
                              ),
                            )
                                : Image.asset(
                              'assets/images/zing.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        // Verification badge if applicable
                        if (user.role.toLowerCase() == 'admin' || user.role.toLowerCase() == 'owner')
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.elasticOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: child,
                                );
                              },
                              child: Container(
                                height: 32,
                                width: 32,
                                decoration: BoxDecoration(
                                  color: user.role.toLowerCase() == 'admin' ? cs.secondary : ZingColors.warning,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: cs.onPrimary, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(
                                    user.role.toLowerCase() == 'admin'
                                        ? Icons.verified_user
                                        : Icons.store,
                                    color: cs.onPrimary,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // User name with animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    user.name,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // User email with animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    user.email,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: cs.onPrimary.withOpacity(0.9),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Role badge with animation
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.onPrimary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: cs.onPrimary.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      user.role.toUpperCase(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimary,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  // Enhanced profile info card
  Widget _buildEnhancedProfileInfoCard(CustomUser user, double screenWidth) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: ZingShadows.soft,
        ),
        child: Column(
          children: [
            // Phone number
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone,
                  color: cs.primary,
                  size: 20,
                ),
              ),
              title: Text(
                'Phone',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              subtitle: Text(
                user.phoneNumber.isNotEmpty ? user.phoneNumber : 'No phone number',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.content_copy,
                  color: cs.primary,
                  size: 20,
                ),
                onPressed: () {
                  // Copy to clipboard
                  if (user.phoneNumber.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: user.phoneNumber));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Phone number copied to clipboard'),
                        backgroundColor: ZingColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  }
                },
              ),
            ),

            Divider(color: cs.outline.withOpacity(0.3)),

            // Email
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.tertiary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.email,
                  color: cs.tertiary,
                  size: 20,
                ),
              ),
              title: Text(
                'Email',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              subtitle: Text(
                user.email,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.content_copy,
                  color: cs.tertiary,
                  size: 20,
                ),
                onPressed: () {
                  // Copy to clipboard
                  Clipboard.setData(ClipboardData(text: user.email));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Email copied to clipboard'),
                      backgroundColor: ZingColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(16),
                    ),
                  );
                },
              ),
            ),

            // Address section if available in user model
            if (user.address != null && user.address!.isNotEmpty)
              Column(
                children: [
                  Divider(color: cs.outline.withOpacity(0.3)),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.secondary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on,
                        color: cs.secondary,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'Address',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    subtitle: Text(
                      user.address!,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  // Enhanced profile options with animations
  Widget _buildEnhancedProfileOptions(BuildContext context, double screenWidth, CustomUser user) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final options = <Map<String, dynamic>>[
      {
        'icon': Icons.history,
        'title': 'Order History',
        'subtitle': 'View your past orders and track current ones',
        'color': cs.tertiary,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => OrderHistoryPage()),
          );
        },
      },
      {
        'icon': Icons.favorite,
        'title': 'Favorite Stores',
        'subtitle': 'Manage your favorite shops',
        'color': ZingColors.warning,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FavouriteStoreScreen()),
          );
        },
      },
      // Store Management link for owners
      if (user.role.toLowerCase() == 'owner')
        {
          'icon': Icons.store,
          'title': 'Store Management',
          'subtitle': 'Manage your store, products and orders',
          'color': cs.tertiary,
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const StoreManagementWidget()),
            );
          },
        },
      // Admin panel link for admins
      if (user.role.toLowerCase() == 'admin')
        {
          'icon': Icons.admin_panel_settings,
          'title': 'Admin Panel',
          'subtitle': 'Manage users, stores and platform settings',
          'color': cs.secondary,
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AdminPanelDashboard()),
            );
          },
        },
      {
        'icon': Icons.settings,
        'title': 'Settings',
        'subtitle': 'App preferences and account settings',
        'color': ZingColors.success,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage()),
          );
        },
      },
      {
        'icon': Icons.help_outline,
        'title': 'Help & Support',
        'subtitle': 'Contact us and FAQ',
        'color': cs.tertiary,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Help & Support will be available soon.')),
          );
        },
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: AnimationLimiter(
        child: Column(
          children: List.generate(
            options.length,
                (index) => AnimationConfiguration.staggeredList(
              position: index,
              duration: const Duration(milliseconds: 600),
              delay: Duration(milliseconds: 100 * index),
              child: SlideAnimation(
                verticalOffset: 50,
                child: FadeInAnimation(
                  child: _buildProfileOptionItem(
                    icon: options[index]['icon'] as IconData,
                    title: options[index]['title'] as String,
                    subtitle: options[index]['subtitle'] as String,
                    color: options[index]['color'] as Color,
                    onTap: options[index]['onTap'] as VoidCallback,
                    isLast: index == options.length - 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced profile option item
  Widget _buildProfileOptionItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: ZingShadows.soft,
      ),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),

              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.arrow_forward_ios,
                color: cs.onSurfaceVariant,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Enhanced action buttons
  Widget _buildEnhancedActionButtons(BuildContext context, double screenWidth) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Edit profile button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfilePage(),
                ),
              );
              HapticFeedback.mediumImpact();
            },
            icon: const Icon(Icons.edit),
            label: Text(
              'Edit Profile',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.onPrimary,
              ),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: Size(screenWidth - 48, 56),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              elevation: 0,
            ),
          ),

          const SizedBox(height: 16),

          // Logout button
          OutlinedButton.icon(
            onPressed: () async {
              // Show confirmation dialog
              final shouldLogout = await _showLogoutConfirmationDialog(context);
              if (shouldLogout) {
                await Provider.of<CustomUserProvider>(context, listen: false).signOut();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            icon: const Icon(Icons.logout),
            label: Text(
              'Log Out',
              style: theme.textTheme.titleLarge?.copyWith(
                color: cs.error,
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: Size(screenWidth - 48, 56),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error, width: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // Logout confirmation dialog
  Future<bool> _showLogoutConfirmationDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.logout,
                  color: cs.error,
                  size: 32,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Log Out',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: cs.onSurface,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Are you sure you want to log out of your account?',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: cs.onSurfaceVariant,
                        side: BorderSide(color: cs.onSurfaceVariant.withOpacity(0.5)),
                      ),
                      child: Text(
                        'Cancel',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        elevation: 0,
                      ),
                      child: Text(
                        'Log Out',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: cs.onError,
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
    ) ?? false;
  }
}
