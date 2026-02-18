import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zing/Cart/CartProvider.dart';
import 'package:zing/Cart/CartScreen.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/screen/HomeScreen.dart';
import 'package:zing/screen/SearchExploreScreen.dart';
import 'package:zing/screen/UserScreens/OrderHistoryPage.dart';
import 'package:zing/screen/UserScreens/UserProfile.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final userProvider = Provider.of<CustomUserProvider>(context);
    final user = userProvider.user;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: cs.surface,
        systemNavigationBarIconBrightness:
            theme.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            HeroMode(
              enabled: _selectedIndex == 0,
              child: const HomePageScreen(),
            ),
            HeroMode(
              enabled: _selectedIndex == 1,
              child: const SearchExploreScreen(),
            ),
            HeroMode(
              enabled: _selectedIndex == 2,
              child: user != null
                  ? CartScreen(userId: user.id, showAppBar: false)
                  : _buildLoginRequired('Cart'),
            ),
            HeroMode(
              enabled: _selectedIndex == 3,
              child: user != null
                  ? OrderHistoryPage()
                  : _buildLoginRequired('Orders'),
            ),
            HeroMode(
              enabled: _selectedIndex == 4,
              child: user != null
                  ? UserProfilePage()
                  : _buildLoginRequired('Profile'),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: NavigationBar(
              height: 72,
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                HapticFeedback.lightImpact();
                setState(() => _selectedIndex = index);
              },
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              indicatorColor: cs.primary.withOpacity(0.12),
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Home',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.explore_outlined),
                  selectedIcon: Icon(Icons.explore_rounded),
                  label: 'Explore',
                ),
                NavigationDestination(
                  icon: Consumer<CartProvider>(
                    builder: (context, cart, child) {
                      return Badge(
                        isLabelVisible: cart.items.isNotEmpty,
                        label: Text('${cart.items.length}'),
                        backgroundColor: cs.secondary,
                        child: const Icon(Icons.shopping_cart_outlined),
                      );
                    },
                  ),
                  selectedIcon: Consumer<CartProvider>(
                    builder: (context, cart, child) {
                      return Badge(
                        isLabelVisible: cart.items.isNotEmpty,
                        label: Text('${cart.items.length}'),
                        backgroundColor: cs.secondary,
                        child: const Icon(Icons.shopping_cart_rounded),
                      );
                    },
                  ),
                  label: 'Cart',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'Orders',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRequired(String feature) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.login_rounded,
              size: 80,
              color: cs.primary.withOpacity(0.5),
            ),
            const SizedBox(height: ZingSpacing.lg),
            Text(
              'Login Required',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Please log in to access $feature',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: ZingSpacing.xl),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              icon: const Icon(Icons.login),
              label: const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
