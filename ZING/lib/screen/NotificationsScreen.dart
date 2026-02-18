import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:zing/Modal/NotificationModel.dart';
import 'package:zing/Service/NotificationProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Shared/zing_empty_state.dart';
import 'package:zing/Widgets/Shared/zing_shimmer.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<NotificationProvider>(context, listen: false).startListening();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: provider.markAllAsRead,
                child: Text('Mark all read', style: theme.textTheme.titleSmall?.copyWith(color: cs.primary)),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return _buildShimmerLoading();
          }

          if (provider.notifications.isEmpty) {
            return const ZingEmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'No notifications',
              subtitle: 'You\'re all caught up! Check back later for updates.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => provider.startListening(),
            child: ListView(
              padding: const EdgeInsets.only(bottom: ZingSpacing.xl),
              children: [
                if (provider.todayNotifications.isNotEmpty)
                  _buildGroup('Today', provider.todayNotifications, theme),
                if (provider.yesterdayNotifications.isNotEmpty)
                  _buildGroup('Yesterday', provider.yesterdayNotifications, theme),
                if (provider.earlierNotifications.isNotEmpty)
                  _buildGroup('Earlier', provider.earlierNotifications, theme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(ZingSpacing.md),
      itemCount: 5,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            ZingShimmer.circle(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ZingShimmer.box(height: 14, width: 180),
                  const SizedBox(height: 8),
                  ZingShimmer.box(height: 12, width: 240),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroup(String title, List<ZingNotification> items, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(ZingSpacing.lg, ZingSpacing.lg, ZingSpacing.lg, ZingSpacing.sm),
          child: Text(title, style: theme.textTheme.titleSmall),
        ),
        ...items.map((n) => _buildNotificationTile(n, theme)),
      ],
    );
  }

  Widget _buildNotificationTile(ZingNotification notification, ThemeData theme) {
    final cs = theme.colorScheme;
    final timeFormat = DateFormat.jm();
    final icon = _getIcon(notification.type);
    final iconColor = _getIconColor(notification.type, cs);

    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          Provider.of<NotificationProvider>(context, listen: false)
              .markAsRead(notification.id);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: ZingSpacing.lg, vertical: 14),
        color: notification.isRead ? Colors.transparent : cs.primary.withOpacity(0.03),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                      Text(
                        timeFormat.format(notification.createdAt.toDate()),
                        style: theme.textTheme.labelSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8, top: 6),
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'order': return Icons.receipt_long_rounded;
      case 'promo': return Icons.local_offer_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getIconColor(String type, ColorScheme cs) {
    switch (type) {
      case 'order': return ZingColors.success;
      case 'promo': return cs.secondary;
      default: return cs.primary;
    }
  }
}
