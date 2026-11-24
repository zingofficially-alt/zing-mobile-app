import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:zing/Cart/CartProvider.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/OrderProvider.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Recommendations/RecommendedStoresRow.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';
import 'package:zing/Widgets/Shared/zing_shimmer.dart';

enum _OrderFilter { active, past }

class OrderHistoryPage extends StatefulWidget {
  /// Kept for older callers; the back button now appears only when the page
  /// was pushed.
  final bool isRootTab;

  const OrderHistoryPage({super.key, this.isRootTab = false});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  List<Orders> _orders = const [];
  bool _loading = true;
  String? _error;
  _OrderFilter _filter = _OrderFilter.active;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOrders());
  }

  Future<void> _loadOrders() async {
    final user = Provider.of<CustomUserProvider>(context, listen: false).currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = _orders.isEmpty;
      _error = null;
    });
    try {
      final orders = await Provider.of<OrderProvider>(context, listen: false)
          .fetchUserOrdersAcrossStores(user.id);
      orders.sort((a, b) => b.placedAt.compareTo(a.placedAt));
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
        // Land on Past when nothing is in progress.
        if (orders.isNotEmpty && orders.every((o) => OrderStatus.isFinal(o.status))) {
          _filter = _OrderFilter.past;
        }
      });
      Provider.of<RecommendationProvider>(context, listen: false)
          .fetchRecommendations(placement: RecommendationProvider.postOrderStores);
    } catch (e) {
      debugPrint('Error loading orders: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'We couldn’t load your orders. Pull down to try again.';
        });
      }
    }
  }

  void _openOrder(Orders order, Store? store) async {
    await showZingSheet<void>(
      context,
      builder: (_) => _OrderDetailSheet(order: order, store: store),
    );
    if (mounted) setState(() {}); // status may have changed (cancel)
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<CustomUserProvider>(context).currentUser;
    final stores = Provider.of<StoreProvider>(context).stores;
    Store? storeFor(Orders o) {
      for (final s in stores) {
        if (s.id == o.storeId) return s;
      }
      return null;
    }

    final active = _orders.where((o) => !OrderStatus.isFinal(o.status)).toList();
    final past = _orders.where((o) => OrderStatus.isFinal(o.status)).toList();
    final shown = _filter == _OrderFilter.active ? active : past;

    return ZingLargeTitlePage(
      title: 'Orders',
      showBack: true,
      onRefresh: _loadOrders,
      slivers: [
        if (user != null && !_loading && _orders.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: ZingSegmented<_OrderFilter>(
                value: _filter,
                segments: {
                  _OrderFilter.active: active.isEmpty ? 'In Progress' : 'In Progress (${active.length})',
                  _OrderFilter.past: 'Past',
                },
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
          ),
        if (_loading)
          SliverList.builder(
            itemCount: 3,
            itemBuilder: (_, __) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: ZingShimmer.box(height: 150, borderRadius: ZingRadius.lg),
            ),
          )
        else if (_error != null)
          SliverToBoxAdapter(
            child: _Message(icon: CupertinoIcons.wifi_exclamationmark, title: 'Something went wrong', body: _error!),
          )
        else if (_orders.isEmpty)
          const SliverToBoxAdapter(
            child: _Message(
              icon: CupertinoIcons.doc_text,
              title: 'No orders yet',
              body: 'When you buy from a store, your orders and their progress show up here.',
            ),
          )
        else if (shown.isEmpty)
          SliverToBoxAdapter(
            child: _Message(
              icon: _filter == _OrderFilter.active ? CupertinoIcons.checkmark_seal : CupertinoIcons.clock,
              title: _filter == _OrderFilter.active ? 'Nothing in progress' : 'No past orders',
              body: _filter == _OrderFilter.active
                  ? 'All your orders are complete.'
                  : 'Completed and cancelled orders will appear here.',
            ),
          )
        else
          SliverList.builder(
            itemCount: shown.length,
            itemBuilder: (context, i) => ZingReveal(
              key: ValueKey(shown[i].id),
              delay: Duration(milliseconds: 40 * (i % 4)),
              child: _OrderCard(
                order: shown[i],
                store: storeFor(shown[i]),
                onTap: () => _openOrder(shown[i], storeFor(shown[i])),
              ),
            ),
          ),
        if (!_loading && user != null)
          SliverToBoxAdapter(
            child: RecommendedStoresRow(
              placement: RecommendationProvider.postOrderStores,
              sectionTitle: 'Shop Again',
              user: user,
            ),
          ),
        if (user == null)
          SliverToBoxAdapter(
            child: _Message(
              icon: CupertinoIcons.person_crop_circle_badge_exclam,
              title: 'Not signed in',
              body: 'Sign in to see your orders.',
              action: ('Sign In', () => Navigator.pushNamed(context, '/login')),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

Color _statusColor(String status) {
  switch (status) {
    case OrderStatus.pending:
      return ZingColors.warning;
    case OrderStatus.processed:
      return ZingColors.accent;
    case OrderStatus.shipped:
      return ZingColors.primary;
    case OrderStatus.delivered:
      return ZingColors.success;
    case OrderStatus.cancelled:
      return ZingColors.error;
    default:
      return ZingColors.textLight;
  }
}

String _money(double v) => 'Rs ${v.toStringAsFixed(v % 1 == 0 ? 0 : 2)}';

class _OrderCard extends StatelessWidget {
  final Orders order;
  final Store? store;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _statusColor(order.status);
    final lines = order.lines;
    final summary = lines.length == 1
        ? '${lines.first.quantity} × ${lines.first.name}'
        : '${order.itemCount} items · ${lines.take(2).map((l) => l.name).join(', ')}${lines.length > 2 ? '…' : ''}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: ZingPressable(
        pressedScale: 0.98,
        onTap: onTap,
        child: Container(
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
                  _StoreThumb(url: store?.imageUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.storeName.isNotEmpty ? order.storeName : (store?.name ?? 'Store'),
                          style: ZingType.headline(cs.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('d MMM yyyy · h:mm a').format(order.placedAt.toDate()),
                          style: ZingType.footnote(cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      OrderStatus.customerLabel(order.status, order.deliveryMethod),
                      style: ZingType.style(12, weight: FontWeight.w600, color: color),
                    ),
                  ),
                ],
              ),
              if (order.status != OrderStatus.cancelled) ...[
                const SizedBox(height: 16),
                _ProgressTrack(order: order),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(summary,
                        style: ZingType.subhead(cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(_money(order.totalPrice), style: ZingType.headline(cs.onSurface)),
                  const SizedBox(width: 4),
                  Icon(CupertinoIcons.chevron_forward,
                      size: 15, color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four-step tracker: Placed → Preparing → Out for delivery/Ready → Done.
class _ProgressTrack extends StatelessWidget {
  final Orders order;
  const _ProgressTrack({required this.order});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final step = OrderStatus.flow.indexOf(order.status).clamp(0, 3);
    final color = _statusColor(order.status);

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++) ...[
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: i <= step ? 1 : 0),
                duration: Duration(milliseconds: 300 + 120 * i),
                curve: ZingMotion.emphasized,
                builder: (_, t, __) => Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color.lerp(cs.surfaceContainerHighest, color, t),
                    shape: BoxShape.circle,
                    boxShadow: i == step
                        ? [BoxShadow(color: color.withValues(alpha: 0.45 * t), blurRadius: 8)]
                        : null,
                  ),
                ),
              ),
              if (i < 3)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: i < step ? 1 : 0),
                        duration: Duration(milliseconds: 420 + 120 * i),
                        curve: ZingMotion.emphasized,
                        builder: (_, t, __) => LinearProgressIndicator(
                          value: t,
                          minHeight: 3,
                          color: color,
                          backgroundColor: cs.surfaceContainerHighest,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Text(
                  OrderStatus.customerLabel(OrderStatus.flow[i], order.deliveryMethod),
                  textAlign: i == 0 ? TextAlign.left : (i == 3 ? TextAlign.right : TextAlign.center),
                  style: ZingType.style(11,
                      weight: i == step ? FontWeight.w600 : FontWeight.w400,
                      color: i <= step ? cs.onSurface : cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _StoreThumb extends StatelessWidget {
  final String? url;
  const _StoreThumb({this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 42,
        height: 42,
        child: (url ?? '').isEmpty
            ? const ZingIconTile(icon: CupertinoIcons.bag_fill, color: ZingColors.primary, size: 42)
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const ZingIconTile(icon: CupertinoIcons.bag_fill, color: ZingColors.primary, size: 42),
              ),
      ),
    );
  }
}

/// Full order: timeline, items, delivery details, totals, cancel.
class _OrderDetailSheet extends StatefulWidget {
  final Orders order;
  final Store? store;
  const _OrderDetailSheet({required this.order, this.store});

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  bool _cancelling = false;
  bool _reordering = false;

  /// Puts this order's items back in the bag at today's price, skipping
  /// anything the store no longer sells or has run out of.
  Future<void> _orderAgain() async {
    final store = widget.store;
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (store == null) {
      showZingToast(context, 'This store is no longer available.', error: true);
      return;
    }
    setState(() => _reordering = true);
    var added = 0;
    final skipped = <String>[];
    for (final line in widget.order.lines) {
      Product? current;
      for (final p in store.products) {
        if (p.id == line.productId) current = p;
      }
      if (current == null || !current.inStock) {
        skipped.add(line.name);
        continue;
      }
      final inBag = cart.items.where((i) => i.id == current!.id).fold<int>(0, (n, i) => n + i.quantity);
      final units = line.quantity.clamp(0, current.quantity - inBag);
      if (units <= 0) {
        skipped.add(line.name);
        continue;
      }
      final item = CartItem(
        id: current.id,
        name: current.name,
        price: current.effectivePrice,
        imageUrl: current.imageUrl,
        storeId: store.id,
        quantity: 1,
      );
      for (var i = 0; i < units; i++) {
        if (!mounted) return;
        await cart.addItem(item, context);
      }
      added += units;
    }
    if (!mounted) return;
    setState(() => _reordering = false);
    if (added == 0) {
      showZingToast(context, 'None of these items are available right now.', error: true);
      return;
    }
    Navigator.of(context).pop();
    showZingToast(
      context,
      skipped.isEmpty
          ? 'Added $added ${added == 1 ? 'item' : 'items'} to your bag'
          : 'Added $added to your bag. Unavailable: ${skipped.join(', ')}',
      icon: CupertinoIcons.bag_fill_badge_plus,
    );
  }

  Future<void> _cancel() async {
    final ok = await showZingAlert(
      context,
      title: 'Cancel this order?',
      message: 'The store will be told straight away. This can’t be undone.',
      confirmLabel: 'Cancel Order',
      cancelLabel: 'Keep Order',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = true);
    try {
      await Provider.of<OrderProvider>(context, listen: false).cancelOrderAsCustomer(widget.order);
      if (!mounted) return;
      showZingToast(context, 'Order cancelled');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _cancelling = false);
      showZingToast(context, 'Could not cancel: the store may have started on it.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final order = widget.order;
    final fmt = DateFormat('d MMM, h:mm a');
    final cancelled = order.status == OrderStatus.cancelled;
    final steps = cancelled
        ? [OrderStatus.pending, OrderStatus.cancelled]
        : OrderStatus.flow;
    final current = steps.indexOf(order.status);
    final subtotal = order.totalPrice - order.deliveryFee;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(order.storeName.isNotEmpty ? order.storeName : 'Order',
                      style: ZingType.title2(cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(
                    'Order #${order.id.length > 6 ? order.id.substring(0, 6).toUpperCase() : order.id} · ${fmt.format(order.placedAt.toDate())}',
                    style: ZingType.footnote(cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            ZingGroupedSection(
              header: 'Status',
              separatorIndent: 16,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Column(
                    children: [
                      for (var i = 0; i < steps.length; i++)
                        _TimelineRow(
                          label: OrderStatus.customerLabel(steps[i], order.deliveryMethod),
                          time: order.reachedAt(steps[i]) == null
                              ? null
                              : fmt.format(order.reachedAt(steps[i])!.toDate()),
                          done: i <= current,
                          current: i == current,
                          color: _statusColor(order.status),
                          last: i == steps.length - 1,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            ZingGroupedSection(
              header: '${order.itemCount} ${order.itemCount == 1 ? 'item' : 'items'}',
              separatorIndent: 16,
              children: [
                for (final line in order.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text('${line.quantity}×', style: ZingType.body(cs.onSurfaceVariant)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(line.name, style: ZingType.body(cs.onSurface))),
                        Text(_money(line.total), style: ZingType.body(cs.onSurface)),
                      ],
                    ),
                  ),
              ],
            ),
            ZingGroupedSection(
              header: order.isHomeDelivery ? 'Delivery' : 'Pickup',
              children: [
                ZingListRow(
                  icon: order.isHomeDelivery ? CupertinoIcons.car_detailed : CupertinoIcons.bag_fill,
                  iconColor: order.isHomeDelivery ? ZingColors.success : ZingColors.warning,
                  title: order.isHomeDelivery ? 'Home Delivery' : 'Collect from store',
                  subtitle: order.isHomeDelivery
                      ? (order.deliveryAddress ?? 'No address recorded')
                      : widget.store?.name,
                ),
              ],
            ),
            ZingGroupedSection(
              header: 'Payment',
              footer: 'Pay the store in cash when you ${order.isHomeDelivery ? 'receive' : 'collect'} your order.',
              separatorIndent: 16,
              children: [
                _amountRow(context, 'Subtotal', subtotal),
                if (order.deliveryFee > 0) _amountRow(context, 'Delivery', order.deliveryFee),
                _amountRow(context, 'Total', order.totalPrice, bold: true),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: ZingButton(
                label: 'Order Again',
                icon: CupertinoIcons.arrow_2_circlepath,
                loading: _reordering,
                onPressed: _orderAgain,
              ),
            ),
            if (order.canCustomerCancel)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: ZingButton(
                  label: 'Cancel Order',
                  tinted: true,
                  destructive: true,
                  loading: _cancelling,
                  onPressed: _cancel,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(BuildContext context, String label, double amount, {bool bold = false}) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? ZingType.headline(cs.onSurface) : ZingType.body(cs.onSurface))),
          Text(_money(amount), style: bold ? ZingType.headline(cs.onSurface) : ZingType.body(cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final String? time;
  final bool done;
  final bool current;
  final bool last;
  final Color color;

  const _TimelineRow({
    required this.label,
    required this.time,
    required this.done,
    required this.current,
    required this.last,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dot = done ? color : cs.surfaceContainerHighest;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: current ? Border.all(color: color.withValues(alpha: 0.3), width: 3) : null,
                  ),
                  child: done && !current
                      ? const Icon(CupertinoIcons.checkmark, size: 9, color: Colors.white)
                      : null,
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: done ? color.withValues(alpha: 0.5) : cs.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: ZingType.body(done ? cs.onSurface : cs.onSurfaceVariant)
                          .copyWith(fontWeight: current ? FontWeight.w600 : FontWeight.w400, height: 1),
                    ),
                  ),
                  if (time != null) Text(time!, style: ZingType.footnote(cs.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final (String, VoidCallback)? action;

  const _Message({required this.icon, required this.title, required this.body, this.action});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ZingReveal(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(40, 48, 40, 24),
        child: Column(
          children: [
            Icon(icon, size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.45)),
            const SizedBox(height: 14),
            Text(title, style: ZingType.title3(cs.onSurface), textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(body, style: ZingType.subhead(cs.onSurfaceVariant), textAlign: TextAlign.center),
            if (action != null) ...[
              const SizedBox(height: 20),
              ZingButton(label: action!.$1, onPressed: action!.$2),
            ],
          ],
        ),
      ),
    );
  }
}
