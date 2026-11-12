import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:zing/Service/ThemeProvider.dart';
import '../Service/CoustomUserProvider.dart';
import '../Service/OrderProvider.dart';
import '../Service/StoreProvider.dart';
import '../Service/RecommendationProvider.dart';
import '../Modal/CoustomUser.dart';
import '../Widgets/Recommendations/RecommendedProductsRow.dart';
import 'CartProvider.dart';


// CartScreen Widget
class CartScreen extends StatefulWidget {
  final String userId;
  final bool showAppBar; // Kept for backward compatibility

  const CartScreen({Key? key, required this.userId, this.showAppBar = true}) : super(key: key);

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isProcessingCheckout = false;
  String? _selectedDeliveryMethod;
  final _addressController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Set the user ID for the cart provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.setUserId(widget.userId);
      await cartProvider.loadCartFromFirestore(context);

      // Fetch cart recommendations after cart items are loaded
      if (!mounted) return;
      final recProvider =
          Provider.of<RecommendationProvider>(context, listen: false);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: Text(
          'My Cart',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: cs.onPrimary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cs.primary,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: cs.onPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        iconTheme: IconThemeData(color: cs.onPrimary),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              return Padding(
                padding: const EdgeInsets.only(right: ZingSpacing.md),
                child: Center(
                  child: Badge(
                    backgroundColor: cs.secondary,
                    label: Text(
                      '${cartProvider.items.length}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    isLabelVisible: cartProvider.items.isNotEmpty,
                    child: Icon(Icons.shopping_cart_outlined, color: cs.onPrimary),
                  ),
                ),
              );
            },
          ),
        ],
      ) : null,
      body: SafeArea(
        top: !widget.showAppBar,
        child: Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            if (cartProvider.isLoading) {
              return _buildLoadingState();
            }

            if (cartProvider.items.isEmpty) {
              return _buildEmptyCart();
            }

            return _buildCartList(context, cartProvider);
          },
        ),
      ),
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.isLoading || cartProvider.items.isEmpty) {
            return const SizedBox.shrink();
          }
          return _buildCheckoutButton(context, cartProvider);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: cs.primary,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 20),
          Text(
            'Loading your cart...',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCart() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: FadeIn(
        duration: const Duration(milliseconds: 600),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.shopping_cart_outlined,
                  size: 52,
                  color: cs.primary,
                ),
              ),
              const SizedBox(height: ZingSpacing.lg),
              Text(
                'Your cart is empty',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: ZingSpacing.sm),
              Text(
                'Browse stores and add items\nto get started',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                ),
              ),
              const SizedBox(height: ZingSpacing.xl),
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, "/home"),
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: Text(
                  'Continue Shopping',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartList(BuildContext context, CartProvider cartProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.only(
        left: ZingSpacing.md,
        right: ZingSpacing.md,
        top: ZingSpacing.md,
        bottom: ZingSpacing.md,
      ),
      children: [
        // Cart summary card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withOpacity(0.75)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.onPrimary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.shopping_bag_outlined, color: cs.onPrimary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cartProvider.items.length} item${cartProvider.items.length == 1 ? '' : 's'} in cart',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        color: cs.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Subtotal: Rs ${cartProvider.totalPrice.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: cs.onPrimary.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: ZingSpacing.md),

        // Cart items
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cartProvider.items.length,
          itemBuilder: (context, index) {
            final cartItem = cartProvider.items[index];

            return FadeInUp(
              duration: Duration(milliseconds: 250 + (index * 80)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: ZingShadows.medium,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Product image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: cartItem.imageUrl != null && cartItem.imageUrl!.isNotEmpty
                            ? Image.network(
                                cartItem.imageUrl!,
                                width: 78,
                                height: 78,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 78,
                                  height: 78,
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(Icons.image_not_supported_outlined,
                                      color: cs.onSurfaceVariant),
                                ),
                              )
                            : Container(
                                width: 78,
                                height: 78,
                                color: cs.surfaceContainerHighest,
                                child: Icon(Icons.inventory_2_outlined,
                                    color: cs.onSurfaceVariant),
                              ),
                      ),

                      const SizedBox(width: 14),

                      // Item details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cartItem.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Rs ${cartItem.price.toStringAsFixed(2)}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Quantity selector
                            Row(
                              children: [
                                _buildQuantityButton(
                                  Icons.remove,
                                  () {
                                    if (cartItem.quantity > 1) {
                                      cartProvider.updateItemQuantity(
                                        cartItem, cartItem.quantity - 1, context,
                                      );
                                    }
                                  },
                                  cartItem.quantity <= 1,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${cartItem.quantity}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _buildQuantityButton(
                                  Icons.add,
                                  () {
                                    cartProvider.updateItemQuantity(
                                      cartItem, cartItem.quantity + 1, context,
                                    );
                                  },
                                  false,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Remove button
                      GestureDetector(
                        onTap: () {
                          final removedItem = cartItem;
                          cartProvider.removeItem(cartItem, context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${cartItem.name} removed',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onPrimary,
                                  fontSize: 13,
                                ),
                              ),
                              action: SnackBarAction(
                                label: 'UNDO',
                                textColor: cs.tertiary,
                                onPressed: () {
                                  cartProvider.addItem(removedItem, context);
                                },
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.error.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.delete_outline_rounded,
                              color: cs.error, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: ZingSpacing.md),

        // Delivery options
        Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: ZingShadows.medium,
          ),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_shipping_outlined,
                          color: cs.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Delivery Method',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Store pickup option
                _buildDeliveryOption(
                  icon: Icons.storefront_outlined,
                  title: 'Pickup from Store',
                  subtitle: 'Free',
                  value: 'Pickup',
                ),
                const SizedBox(height: ZingSpacing.sm),

                // Home delivery option
                _buildDeliveryOption(
                  icon: Icons.home_outlined,
                  title: 'Home Delivery',
                  subtitle: 'Rs 50.00',
                  value: 'Home Delivery',
                ),

                // Address input (appears when home delivery is selected)
                if (_selectedDeliveryMethod == 'Home Delivery')
                  Padding(
                    padding: const EdgeInsets.only(top: ZingSpacing.md),
                    child: Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          labelText: 'Delivery Address',
                          hintText: 'Enter your full address',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your delivery address';
                          }
                          return null;
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Recommendations above checkout
        RecommendedProductsRow(
          placement: RecommendationProvider.cartBoughtTogether,
          sectionTitle: 'Customers Also Bought',
          fallbackProducts: cartProvider.items
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
      ],
    );
  }

  Widget _buildDeliveryOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = _selectedDeliveryMethod == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedDeliveryMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primary.withOpacity(0.06)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? cs.primary : cs.onSurfaceVariant,
                size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? cs.primary : cs.outline,
                  width: isSelected ? 5 : 1.5,
                ),
                color: isSelected ? cs.primary : Colors.transparent,
              ),
              child: isSelected
                  ? Center(
                      child: Icon(Icons.check, size: 10, color: cs.onPrimary),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed, bool disabled) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: disabled
              ? cs.surfaceContainerHighest
              : cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(
          icon,
          size: 15,
          color: disabled ? cs.outline : cs.primary,
        ),
      ),
    );
  }

  Widget _buildCheckoutButton(BuildContext context, CartProvider cartProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Calculate total (adding delivery fee if home delivery is selected)
    final total = cartProvider.totalPrice +
        (_selectedDeliveryMethod == 'Home Delivery' ? 50.0 : 0.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Total',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Rs ${total.toStringAsFixed(2)}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessingCheckout ? null : () async {
                  // Validate delivery method selection
                  if (_selectedDeliveryMethod == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a delivery method'),
                      ),
                    );
                    return;
                  }

                  // Validate address for home delivery
                  if (_selectedDeliveryMethod == 'Home Delivery') {
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }
                  }

                  // Process checkout
                  setState(() {
                    _isProcessingCheckout = true;
                  });

                  try {
                    final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
                    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
                    final storeProvider = Provider.of<StoreProvider>(context, listen: false);

                    final CustomUser? currentUser = userProvider.user;

                    if (currentUser == null || cartProvider.items.isEmpty) {
                      throw Exception('User or cart items not available');
                    }

                    final isHomeDelivery = _selectedDeliveryMethod == 'Home Delivery';
                    const double deliveryFee = 50.0;

                    // Group cart items by the store they belong to, so each
                    // store receives its own order.
                    final Map<Store, List<CartItem>> itemsByStore = {};
                    for (final item in cartProvider.items) {
                      final store = storeProvider.stores.firstWhere(
                        (s) => item.storeId != null && item.storeId!.isNotEmpty
                            ? s.id == item.storeId
                            : s.products.any((p) => p.id == item.id),
                        orElse: () => throw Exception('Store not found for "${item.name}"'),
                      );
                      itemsByStore.putIfAbsent(store, () => []).add(item);
                    }

                    for (final entry in itemsByStore.entries) {
                      // Convert cart lines into order products. One entry per
                      // unit, matching how "Buy Now" records quantities.
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
                      final subtotal = entry.value.fold<double>(
                          0, (sum, item) => sum + item.totalPrice);

                      await orderProvider.placeOrder(
                        currentUser.id,
                        entry.key,
                        products,
                        subtotal + (isHomeDelivery ? deliveryFee : 0.0),
                        _selectedDeliveryMethod!,
                        currentUser,
                        deliveryFee: isHomeDelivery ? deliveryFee : 0.0,
                        deliveryAddress:
                            isHomeDelivery ? _addressController.text.trim() : null,
                      );
                    }

                    // Log purchase-complete event for Retail API
                    final recProvider = Provider.of<RecommendationProvider>(
                        context,
                        listen: false);
                    recProvider.logEvent(
                      eventType: 'purchase-complete',
                      productIds: cartProvider.items
                          .map((item) =>
                              'product_${item.storeId ?? ''}_${item.id}')
                          .toList(),
                      purchaseAmount: total,
                      transactionId:
                          'txn_${currentUser.id}_${DateTime.now().millisecondsSinceEpoch}',
                    );

                    await cartProvider.clearCart(context);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Order placed successfully!'),
                          backgroundColor: ZingColors.success,
                        ),
                      );

                      Navigator.pop(context);
                    }
                  } catch (e) {
                    print("Error placing order: $e");
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to place order: ${e.toString()}'),
                          backgroundColor: cs.error,
                        ),
                      );

                      setState(() {
                        _isProcessingCheckout = false;
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 17),
                ),
                child: _isProcessingCheckout
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: cs.onPrimary,
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Processing...',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              color: cs.onPrimary,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Place Order',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimary,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
