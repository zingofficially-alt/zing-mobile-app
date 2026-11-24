import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';

import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:zing/Service/OrderProvider.dart';
import 'package:zing/Service/RecommendationProvider.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Widgets/Recommendations/RecommendedProductsRow.dart';
import 'package:zing/Cart/CartProvider.dart';

enum _Fulfilment { pickup, delivery }

/// Fee charged when a store offers home delivery but has not set a price.
const double _defaultDeliveryFee = 50.0;

class CartScreen extends StatefulWidget {
  final String userId;

  /// True when pushed as its own page (shows a back button); false inside
  /// the Cart tab.
  final bool showAppBar;

  const CartScreen({super.key, required this.userId, this.showAppBar = true});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isProcessingCheckout = false;
  _Fulfilment _fulfilment = _Fulfilment.pickup;
  final _addressController = TextEditingController();
  bool _addressPrefilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.setUserId(widget.userId);
      await cartProvider.loadCart(context);

      if (!mounted) return;
      final recProvider = Provider.of<RecommendationProvider>(context, listen: false);
      final productIds = cartProvider.items
          .map((item) => 'product_${item.storeId ?? ''}_${item.id}')
          .where((id) => !id.contains('_null_') && !id.endsWith('_'))
          .toList();
      recProvider.fetchRecommendations(
        placement: RecommendationProvider.cartBoughtTogether,
        productIds: productIds,
      );
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- helpers

  /// Cart lines grouped by the store that sells them, in cart order.
  Map<Store?, List<CartItem>> _groupByStore(List<CartItem> items, List<Store> stores) {
    final grouped = <Store?, List<CartItem>>{};
    for (final item in items) {
      Store? store;
      for (final s in stores) {
        final matches = (item.storeId ?? '').isNotEmpty
            ? s.id == item.storeId
            : s.products.any((p) => p.id == item.id);
        if (matches) {
          store = s;
          break;
        }
      }
      grouped.putIfAbsent(store, () => []).add(item);
    }
    return grouped;
  }

  static bool _offersDelivery(Store? store) {
    if (store == null) return false;
    final options = store.deliveryOptions ?? const <String>[];
    // Stores that never set options keep the old behaviour (delivery allowed).
    return options.isEmpty || options.any((o) => o.contains('Home Delivery'));
  }

  static double _feeFor(Store store) => store.deliveryCost ?? _defaultDeliveryFee;

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final user = Provider.of<CustomUserProvider>(context).user;
    if (!_addressPrefilled && user != null && user.address.isNotEmpty) {
      _addressController.text = user.address;
      _addressPrefilled = true;
    }

    return Consumer2<CartProvider, StoreProvider>(
      builder: (context, cart, storeProvider, _) {
        final grouped = _groupByStore(cart.items, storeProvider.stores);
        final deliveryPossible =
            grouped.keys.isNotEmpty && grouped.keys.every(_offersDelivery);
        if (!deliveryPossible && _fulfilment == _Fulfilment.delivery) {
          _fulfilment = _Fulfilment.pickup;
        }
        final deliveryFee = _fulfilment == _Fulfilment.delivery
            ? grouped.keys.whereType<Store>().fold<double>(0, (sum, s) => sum + _feeFor(s))
            : 0.0;
        final total = cart.totalPrice + deliveryFee;
        final count = cart.items.fold<int>(0, (n, i) => n + i.quantity);

        return Scaffold(
          extendBody: true,
          body: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              CupertinoSliverNavigationBar(
                largeTitle: const Text('Bag'),
                automaticallyImplyLeading: false,
                leading: widget.showAppBar && Navigator.of(context).canPop()
                    ? CupertinoNavigationBarBackButton(
                        color: cs.primary,
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    : null,
                trailing: cart.items.isEmpty
                    ? null
                    : Text('$count ${count == 1 ? 'item' : 'items'}',
                        style: ZingType.subhead(cs.onSurfaceVariant)),
                backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.82),
                border: null,
                stretch: true,
              ),
              if (cart.isLoading)
                const SliverFillRemaining(hasScrollBody: false, child: ZingSpinner())
              else if (cart.items.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _buildEmptyCart())
              else ...[
                for (final entry in grouped.entries)
                  SliverToBoxAdapter(child: _buildStoreGroup(entry.key, entry.value, cart)),
                SliverToBoxAdapter(
                  child: _buildFulfilment(grouped, deliveryPossible),
                ),
                SliverToBoxAdapter(
                  child: ZingGroupedSection(
                    header: 'Summary',
                    separatorIndent: 16,
                    children: [
                      _summaryRow('Subtotal', cart.totalPrice),
                      _summaryRow(
                        'Delivery',
                        deliveryFee,
                        zeroLabel: _fulfilment == _Fulfilment.pickup ? 'Pickup · Free' : 'Free',
                      ),
                      _summaryRow('Total', total, bold: true),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: RecommendedProductsRow(
                    placement: RecommendationProvider.cartBoughtTogether,
                    sectionTitle: 'Customers Also Bought',
                    fallbackProducts: cart.items
                        .map((item) => Product(
                              id: item.id,
                              name: item.name,
                              price: item.price,
                              imageUrl: item.imageUrl,
                              isAvailable: true,
                              quantity: item.quantity,
                            ))
                        .toList(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 190),
                ),
              ],
            ],
          ),
          bottomNavigationBar: cart.isLoading || cart.items.isEmpty
              ? null
              : _buildCheckoutBar(cart, grouped, total, deliveryFee),
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 0, 40, 140),
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
              child: Icon(CupertinoIcons.bag, size: 44, color: cs.primary),
            ),
            const SizedBox(height: 22),
            Text('Your bag is empty', style: ZingType.title2(cs.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Products you add from any store will appear here, ready to check out.',
              style: ZingType.subhead(cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreGroup(Store? store, List<CartItem> items, CartProvider cart) {
    return ZingReveal(
      child: ZingGroupedSection(
        header: store?.name ?? 'Other items',
        separatorIndent: 100,
        footer: _fulfilment == _Fulfilment.delivery && store != null && _offersDelivery(store)
            ? 'Delivery from this store: Rs ${_feeFor(store).toStringAsFixed(0)}'
            : null,
        children: [for (final item in items) _CartLine(item: item, cart: cart)],
      ),
    );
  }

  Widget _buildFulfilment(Map<Store?, List<CartItem>> grouped, bool deliveryPossible) {
    final cs = Theme.of(context).colorScheme;
    final noDeliveryStores = grouped.keys
        .where((s) => !_offersDelivery(s))
        .map((s) => s?.name ?? 'Some items')
        .toList();

    return ZingGroupedSection(
      header: 'How do you want it?',
      separatorIndent: 16,
      footer: !deliveryPossible
          ? '${noDeliveryStores.join(', ')} ${noDeliveryStores.length == 1 ? 'offers' : 'offer'} pickup only.'
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: ZingSegmented<_Fulfilment>(
            value: _fulfilment,
            segments: {
              _Fulfilment.pickup: 'Store Pickup',
              if (deliveryPossible) _Fulfilment.delivery: 'Home Delivery',
            },
            onChanged: (v) => setState(() => _fulfilment = v),
          ),
        ),
        AnimatedSize(
          duration: ZingMotion.medium,
          curve: ZingMotion.emphasized,
          child: _fulfilment == _Fulfilment.delivery
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Delivery address', style: ZingType.footnote(cs.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      CupertinoTextField(
                        controller: _addressController,
                        placeholder: 'House number, street, city',
                        minLines: 2,
                        maxLines: 4,
                        padding: const EdgeInsets.all(12),
                        style: ZingType.body(cs.onSurface),
                        placeholderStyle: ZingType.body(cs.onSurfaceVariant.withValues(alpha: 0.7)),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, double amount, {bool bold = false, String? zeroLabel}) {
    final cs = Theme.of(context).colorScheme;
    final style = bold
        ? ZingType.headline(cs.onSurface)
        : ZingType.body(cs.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? style : ZingType.body(cs.onSurface))),
          Text(
            amount == 0 && zeroLabel != null ? zeroLabel : 'Rs ${amount.toStringAsFixed(2)}',
            style: style,
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar(
    CartProvider cart,
    Map<Store?, List<CartItem>> grouped,
    double total,
    double deliveryFee,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final needsAddress =
        _fulfilment == _Fulfilment.delivery && _addressController.text.trim().isEmpty;

    return ZingGlass(
      opacity: 0.8,
      blur: 30,
      color: theme.brightness == Brightness.dark ? const Color(0xFF161618) : const Color(0xFFF9F9F9),
      border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.55), width: 0.5)),
      child: SafeArea(
        top: false,
        child: Padding(
          // Leave room for the tab bar when shown inside the Cart tab.
          padding: EdgeInsets.fromLTRB(16, 12, 16, widget.showAppBar ? 10 : 72),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Total', style: ZingType.footnote(cs.onSurfaceVariant)),
                    Text('Rs ${total.toStringAsFixed(2)}', style: ZingType.title3(cs.onSurface)),
                  ],
                ),
              ),
              SizedBox(
                width: 180,
                child: ZingButton(
                  label: needsAddress ? 'Add Address' : 'Place Order',
                  loading: _isProcessingCheckout,
                  onPressed: needsAddress
                      ? null
                      : () => _checkout(cart, grouped, total),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ checkout

  Future<void> _checkout(
    CartProvider cartProvider,
    Map<Store?, List<CartItem>> grouped,
    double total,
  ) async {
    final isHomeDelivery = _fulfilment == _Fulfilment.delivery;
    final method = isHomeDelivery ? 'Home Delivery' : 'Pickup';

    final confirmed = await showZingAlert(
      context,
      title: 'Place Order?',
      message: isHomeDelivery
          ? 'Rs ${total.toStringAsFixed(2)} will be paid on delivery to:\n${_addressController.text.trim()}'
          : 'Rs ${total.toStringAsFixed(2)} will be paid when you collect your order.',
      confirmLabel: 'Place Order',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isProcessingCheckout = true);
    HapticFeedback.mediumImpact();

    try {
      final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      final storeProvider = Provider.of<StoreProvider>(context, listen: false);
      final recProvider = Provider.of<RecommendationProvider>(context, listen: false);

      final CustomUser? currentUser = userProvider.user;
      if (currentUser == null || cartProvider.items.isEmpty) {
        throw Exception('User or cart items not available');
      }
      if (grouped.containsKey(null)) {
        final names = grouped[null]!.map((i) => i.name).join(', ');
        throw Exception('These items are no longer sold: $names. Remove them to continue.');
      }

      // One order per store, each with that store's own delivery fee.
      for (final entry in grouped.entries) {
        final store = entry.key!;
        final products = <Product>[
          for (final item in entry.value)
            for (int i = 0; i < item.quantity; i++)
              Product(
                id: item.id,
                name: item.name,
                price: item.price,
                imageUrl: item.imageUrl,
                quantity: 1,
              ),
        ];
        final subtotal = entry.value.fold<double>(0, (sum, item) => sum + item.totalPrice);
        final fee = isHomeDelivery ? _feeFor(store) : 0.0;

        await orderProvider.placeOrder(
          currentUser.id,
          store,
          products,
          subtotal + fee,
          method,
          currentUser,
          deliveryFee: fee,
          deliveryAddress: isHomeDelivery ? _addressController.text.trim() : null,
        );
      }

      // Stock changed; reload so screens show the new counts.
      storeProvider.fetchStores();

      recProvider.logEvent(
        eventType: 'purchase-complete',
        productIds: cartProvider.items
            .map((item) => 'product_${item.storeId ?? ''}_${item.id}')
            .toList(),
        purchaseAmount: total,
        transactionId: 'txn_${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Always clear the cart once the order is placed, even if the customer
      // has already left this screen.
      // ignore: use_build_context_synchronously
      await cartProvider.clearCart(context);

      if (!mounted) return;
      setState(() => _isProcessingCheckout = false);
      HapticFeedback.heavyImpact();
      await showZingAlert(
        context,
        title: 'Order Placed',
        message: grouped.length == 1
            ? 'The store has your order. You’ll get a notification when its status changes.'
            : 'Your ${grouped.length} orders have been sent to the stores. Track them in Orders.',
        confirmLabel: 'Done',
        cancelLabel: null,
      );
      // Only leave when this screen was pushed; inside the tab bar there is
      // nothing to go back to.
      if (mounted && widget.showAppBar && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error placing order: $e');
      if (!mounted) return;
      setState(() => _isProcessingCheckout = false);
      showZingToast(
        context,
        e.toString().replaceFirst('Exception: ', 'Could not place order: '),
        error: true,
      );
    }
  }
}

/// One cart line: swipe left to delete (with undo), stepper for quantity.
class _CartLine extends StatelessWidget {
  final CartItem item;
  final CartProvider cart;
  const _CartLine({required this.item, required this.cart});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    void remove() {
      HapticFeedback.mediumImpact();
      final removed = item;
      cart.removeItem(item, context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${removed.name} removed'),
          action: SnackBarAction(
            label: 'Undo',
            textColor: ZingColors.primaryLight,
            onPressed: () => cart.addItem(removed, context),
          ),
        ));
    }

    return Dismissible(
      key: ValueKey('cart-${item.id}-${item.storeId}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => remove(),
      background: Container(
        color: ZingColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.trash_fill, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text('Delete', style: ZingType.style(15, weight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 72,
                height: 72,
                child: (item.imageUrl ?? '').isEmpty
                    ? Container(
                        color: cs.surfaceContainerHighest,
                        child: Icon(CupertinoIcons.cube_box, color: cs.onSurfaceVariant),
                      )
                    : CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: cs.surfaceContainerHighest,
                          child: Icon(CupertinoIcons.photo, color: cs.onSurfaceVariant),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: ZingType.headline(cs.onSurface), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('Rs ${item.price.toStringAsFixed(2)} each',
                      style: ZingType.footnote(cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Stepper(
                        value: item.quantity,
                        onMinus: item.quantity > 1
                            ? () => cart.updateItemQuantity(item, item.quantity - 1, context)
                            : remove,
                        onPlus: () => cart.updateItemQuantity(item, item.quantity + 1, context),
                        minusIsDelete: item.quantity <= 1,
                      ),
                      const Spacer(),
                      Text('Rs ${item.totalPrice.toStringAsFixed(0)}',
                          style: ZingType.headline(cs.onSurface)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  final int value;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  final bool minusIsDelete;

  const _Stepper({
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.minusIsDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget button(IconData icon, VoidCallback onTap, {Color? color}) => CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(34, 30),
          onPressed: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Icon(icon, size: 16, color: color ?? cs.onSurface),
        );

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(minusIsDelete ? CupertinoIcons.trash : CupertinoIcons.minus, onMinus,
              color: minusIsDelete ? ZingColors.error : null),
          SizedBox(
            width: 26,
            child: AnimatedSwitcher(
              duration: ZingMotion.fast,
              transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
              child: Text('$value',
                  key: ValueKey(value),
                  textAlign: TextAlign.center,
                  style: ZingType.style(15, weight: FontWeight.w600, color: cs.onSurface)),
            ),
          ),
          button(CupertinoIcons.plus, onPlus),
        ],
      ),
    );
  }
}
