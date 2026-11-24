import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zing/Modal/NotificationModel.dart';
import 'package:zing/screen/UserScreens/OrderHistoryPage.dart';
import 'package:zing/Service/NotificationProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';
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

  void _open(ZingNotification n) {
    final provider = Provider.of<NotificationProvider>(context, listen: false);
    if (!n.isRead) provider.markAsRead(n.id);
    if (n.type == 'order') {
      Navigator.of(context).push(zingRoute(const OrderHistoryPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        return ZingLargeTitlePage(
          title: 'Notifications',
          showBack: true,
          onRefresh: () async => provider.startListening(),
          actions: [
            if (provider.unreadCount > 0)
              CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(40, 40),
                onPressed: provider.markAllAsRead,
                child: Text('Read All', style: ZingType.body(cs.primary)),
              ),
          ],
          slivers: [
            if (provider.isLoading)
              SliverList.builder(
                itemCount: 4,
                itemBuilder: (_, __) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: ZingShimmer.box(height: 76, borderRadius: ZingRadius.md),
                ),
              )
            else if (provider.notifications.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 120),
                  child: ZingReveal(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(CupertinoIcons.bell_slash, size: 48,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.45)),
                        const SizedBox(height: 14),
                        Text('You’re all caught up', style: ZingType.title3(cs.onSurface)),
                        const SizedBox(height: 6),
                        Text(
                          'Order updates and offers from stores will appear here.',
                          style: ZingType.subhead(cs.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              _group('Today', provider.todayNotifications, DateFormat.jm()),
              _group('Yesterday', provider.yesterdayNotifications, DateFormat.jm()),
              _group('Earlier', provider.earlierNotifications, DateFormat('d MMM')),
            ],
          ],
        );
      },
    );
  }

  Widget _group(String title, List<ZingNotification> items, DateFormat fmt) {
    if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: ZingReveal(
        child: ZingGroupedSection(
          header: title,
          separatorIndent: 62,
          children: [for (final n in items) _NotificationRow(n: n, fmt: fmt, onTap: () => _open(n))],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final ZingNotification n;
  final DateFormat fmt;
  final VoidCallback onTap;

  const _NotificationRow({required this.n, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (n.type) {
      'order' => (CupertinoIcons.doc_text_fill, ZingColors.success),
      'promo' => (CupertinoIcons.tag_fill, ZingColors.secondary),
      'chat' => (CupertinoIcons.chat_bubble_fill, ZingColors.accent),
      _ => (CupertinoIcons.bell_fill, ZingColors.primary),
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ZingIconTile(icon: icon, color: color, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: ZingType.headline(cs.onSurface).copyWith(
                            fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(fmt.format(n.createdAt.toDate()), style: ZingType.footnote(cs.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(n.body,
                      style: ZingType.subhead(cs.onSurfaceVariant),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            AnimatedContainer(
              duration: ZingMotion.medium,
              width: n.isRead ? 0 : 9,
              height: 9,
              margin: EdgeInsets.only(left: n.isRead ? 0 : 10, top: 6),
              decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }
}
