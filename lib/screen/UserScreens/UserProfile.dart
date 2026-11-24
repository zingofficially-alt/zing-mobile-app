import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zing/AdminPanal/AdminPanalDashBoard.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/screen/HelpSupportScreen.dart';
import 'package:zing/screen/StoreManagement/storeManagementScreen.dart';
import 'package:zing/screen/UserScreens/EditeUser.dart';
import 'package:zing/screen/UserScreens/FavouriteStoreScreen.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';

import 'package:zing/screen/UserScreens/OrderHistoryPage.dart';
import 'package:zing/screen/UserScreens/SettingPage.dart';

/// Profile tab: who you are, your activity, store tools and app settings.
class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showZingAlert(
      context,
      title: 'Sign Out?',
      message: 'You can sign back in at any time with the same account.',
      confirmLabel: 'Sign Out',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await Provider.of<CustomUserProvider>(context, listen: false).signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
  }

  void _push(BuildContext context, Widget page) => Navigator.of(context).push(zingRoute(page));

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<CustomUserProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final user = userProvider.user;

    if (user == null) {
      return const Scaffold(body: ZingSpinner());
    }

    final daysLeft = user.subscriptionDaysLeft();
    var delay = 0;
    Duration next() => Duration(milliseconds: 50 * delay++);

    return ZingLargeTitlePage(
      title: 'Profile',
      actions: [
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(40, 40),
          onPressed: () => _push(context, EditProfilePage()),
          child: Text('Edit', style: ZingType.body(Theme.of(context).colorScheme.primary)),
        ),
      ],
      onRefresh: () async => userProvider.fetchUserDetails(),
      slivers: [
        SliverToBoxAdapter(
          child: ZingReveal(
            delay: next(),
            child: _ProfileHeader(user: user, onTap: () => _push(context, EditProfilePage())),
          ),
        ),
        SliverToBoxAdapter(
          child: ZingReveal(
            delay: next(),
            child: ZingGroupedSection(
              header: 'Activity',
              children: [
                ZingListRow(
                  icon: CupertinoIcons.doc_text_fill,
                  iconColor: ZingColors.accent,
                  title: 'Orders',
                  subtitle: 'Track deliveries and past purchases',
                  onTap: () => _push(context, const OrderHistoryPage()),
                ),
                ZingListRow(
                  icon: CupertinoIcons.heart_fill,
                  iconColor: ZingColors.secondary,
                  title: 'Favourite Stores',
                  value: '${user.favorites?.length ?? 0}',
                  onTap: () => _push(context, const FavouriteStoreScreen()),
                ),
              ],
            ),
          ),
        ),
        if (user.isOwner || user.isAdmin)
          SliverToBoxAdapter(
            child: ZingReveal(
              delay: next(),
              child: ZingGroupedSection(
                header: user.isAdmin ? 'Administration' : 'Your Business',
                footer: user.isOwner && daysLeft != null
                    ? (daysLeft > 0
                        ? 'Your store subscription renews in $daysLeft ${daysLeft == 1 ? 'day' : 'days'}.'
                        : 'Your store subscription has ended. Renew it to stay visible to customers.')
                    : null,
                children: [
                  if (user.isOwner)
                    ZingListRow(
                      icon: CupertinoIcons.bag_fill,
                      iconColor: ZingColors.primary,
                      title: 'Store Management',
                      subtitle: 'Products, orders and store details',
                      trailing: daysLeft != null && daysLeft <= 5
                          ? _StatusPill(
                              label: daysLeft > 0 ? '$daysLeft days' : 'Expired',
                              color: daysLeft > 0 ? ZingColors.warning : ZingColors.error,
                            )
                          : null,
                      onTap: () => _push(context, const StoreManagementWidget()),
                    ),
                  if (user.isAdmin)
                    ZingListRow(
                      icon: CupertinoIcons.shield_lefthalf_fill,
                      iconColor: const Color(0xFF8E8E93),
                      title: 'Admin Panel',
                      subtitle: 'Users, stores, payments and promotions',
                      onTap: () => _push(context, AdminPanelDashboard()),
                    ),
                ],
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: ZingReveal(
            delay: next(),
            child: ZingGroupedSection(
              header: 'Preferences',
              children: [
                ZingListRow(
                  icon: CupertinoIcons.moon_fill,
                  iconColor: const Color(0xFF5856D6),
                  title: 'Dark Mode',
                  trailing: CupertinoSwitch(
                    value: themeProvider.isDarkMode,
                    activeTrackColor: ZingColors.success,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      themeProvider.toggleTheme(v);
                    },
                  ),
                ),
                ZingListRow(
                  icon: CupertinoIcons.gear_alt_fill,
                  iconColor: const Color(0xFF8E8E93),
                  title: 'Settings',
                  subtitle: 'Account, security, notifications',
                  onTap: () => _push(context, SettingsPage()),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ZingReveal(
            delay: next(),
            child: ZingGroupedSection(
              children: [
                ZingListRow(
                  icon: CupertinoIcons.question_circle_fill,
                  iconColor: ZingColors.success,
                  title: 'Help & Support',
                  onTap: () => _push(context, const HelpSupportScreen()),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: ZingReveal(
            delay: next(),
            child: ZingGroupedSection(
              separatorIndent: 16,
              children: [
                ZingListRow(
                  title: 'Sign Out',
                  destructive: true,
                  showChevron: false,
                  onTap: () => _signOut(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Avatar, name and contact summary — the Apple ID card at the top.
class _ProfileHeader extends StatelessWidget {
  final CustomUser user;
  final VoidCallback onTap;
  const _ProfileHeader({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
    final contact = [
      if (user.email.isNotEmpty) user.email,
      if (user.phoneNumber.isNotEmpty) user.phoneNumber,
    ].join('  ·  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: ZingPressable(
        pressedScale: 0.98,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(ZingRadius.lg),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [ZingColors.primaryLight, ZingColors.primary],
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: user.profileImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: user.profileImageUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _Initials(initials),
                      )
                    : _Initials(initials),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.name.isEmpty ? 'Your Name' : user.name,
                            style: ZingType.title3(cs.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (user.isOwner || user.isAdmin) ...[
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: user.isAdmin ? 'Admin' : 'Owner',
                            color: user.isAdmin ? ZingColors.secondary : ZingColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      contact.isEmpty ? 'Add your contact details' : contact,
                      style: ZingType.footnote(cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(CupertinoIcons.chevron_forward,
                  size: 17, color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  final String text;
  const _Initials(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          text.isEmpty ? '?' : text,
          style: ZingType.style(24, weight: FontWeight.w600, color: Colors.white),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(label, style: ZingType.style(12, weight: FontWeight.w600, color: color)),
      );
}
