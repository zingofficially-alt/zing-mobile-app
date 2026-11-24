import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zing/Cart/CartProvider.dart';
import 'package:zing/Cart/CartScreen.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/screen/HomeScreen.dart';
import 'package:zing/screen/SearchExploreScreen.dart';
import 'package:zing/screen/UserScreens/OrderHistoryPage.dart';
import 'package:zing/screen/UserScreens/UserProfile.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  static const _tabs = [
    _Tab('Home', CupertinoIcons.house, CupertinoIcons.house_fill),
    _Tab('Explore', CupertinoIcons.compass, CupertinoIcons.compass_fill),
    _Tab('Cart', CupertinoIcons.bag, CupertinoIcons.bag_fill),
    _Tab('Orders', CupertinoIcons.doc_text, CupertinoIcons.doc_text_fill),
    _Tab('Profile', CupertinoIcons.person_crop_circle, CupertinoIcons.person_crop_circle_fill),
  ];

  void _select(int index) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final user = Provider.of<CustomUserProvider>(context).user;

    Widget page(int i, Widget child) => HeroMode(
          enabled: _selectedIndex == i,
          child: TickerMode(enabled: _selectedIndex == i, child: child),
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarContrastEnforced: false,
        systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            page(0, const HomePageScreen()),
            page(1, const SearchExploreScreen()),
            page(
              2,
              user != null
                  ? CartScreen(userId: user.id, showAppBar: false)
                  : const _SignInPrompt(
                      title: 'Your Bag',
                      icon: CupertinoIcons.bag,
                      message: 'Sign in to save items to your bag and check out from any store.',
                    ),
            ),
            page(
              3,
              user != null
                  ? const OrderHistoryPage()
                  : const _SignInPrompt(
                      title: 'Orders',
                      icon: CupertinoIcons.doc_text,
                      message: 'Sign in to track deliveries and see everything you have ordered.',
                    ),
            ),
            page(
              4,
              user != null
                  ? const UserProfilePage()
                  : const _SignInPrompt(
                      title: 'Profile',
                      icon: CupertinoIcons.person_crop_circle,
                      message: 'Sign in to manage your profile, favourites and settings.',
                    ),
            ),
          ],
        ),
        bottomNavigationBar: _GlassTabBar(
          tabs: _tabs,
          selectedIndex: _selectedIndex,
          onSelect: _select,
        ),
      ),
    );
  }
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const _Tab(this.label, this.icon, this.selectedIcon);
}

/// Frosted tab bar with a hairline top border, like UITabBar.
class _GlassTabBar extends StatelessWidget {
  final List<_Tab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _GlassTabBar({required this.tabs, required this.selectedIndex, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return ZingGlass(
      opacity: 0.72,
      blur: 30,
      color: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF161618)
          : const Color(0xFFF9F9F9),
      border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.55), width: 0.5)),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset : 8, top: 6),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _TabItem(
                  tab: tabs[i],
                  selected: i == selectedIndex,
                  onTap: () => onSelect(i),
                  badge: i == 2
                      ? Consumer<CartProvider>(
                          builder: (_, cart, __) => ZingBadge(count: cart.items.length),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final _Tab tab;
  final bool selected;
  final VoidCallback onTap;
  final Widget? badge;

  const _TabItem({required this.tab, required this.selected, required this.onTap, this.badge});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = selected ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.75);

    return Semantics(
      selected: selected,
      button: true,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The icon pops when it becomes selected.
              TweenAnimationBuilder<double>(
                key: ValueKey(selected),
                tween: Tween(begin: selected ? 0.82 : 1, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(selected ? tab.selectedIcon : tab.icon, size: 25, color: color),
                    if (badge != null) Positioned(right: -10, top: -5, child: badge!),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: ZingMotion.fast,
                style: ZingType.style(10, weight: FontWeight.w500, color: color),
                child: Text(tab.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown on tabs that need an account when nobody is signed in.
class _SignInPrompt extends StatelessWidget {
  final String title;
  final IconData icon;
  final String message;

  const _SignInPrompt({required this.title, required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ZingLargeTitlePage(
      title: title,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 120),
            child: ZingReveal(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 44, color: cs.primary),
                  ),
                  const SizedBox(height: 22),
                  Text('Sign in to continue',
                      style: ZingType.title2(cs.onSurface), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(message,
                      style: ZingType.subhead(cs.onSurfaceVariant), textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  ZingButton(
                    label: 'Sign In',
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                  ),
                  const SizedBox(height: 10),
                  CupertinoButton(
                    onPressed: () => Navigator.pushNamed(context, '/createAccount'),
                    child: Text('Create an account', style: ZingType.body(cs.primary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
