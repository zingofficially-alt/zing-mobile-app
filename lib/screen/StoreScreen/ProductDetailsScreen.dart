import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zing/Cart/CartProvider.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/OrderProvider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:zing/screen/UserScreens/EditeUser.dart';
import 'package:zing/Service/CoustomUserProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zing/Service/StoreProvider.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Shared/zing_ios.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final Store store;

  const ProductDetailScreen({super.key, required this.product, required this.store});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> with SingleTickerProviderStateMixin {
  CustomUser? currentUser;
  bool isLoading = true;
  String? errorMessage;
  String? selectedDeliveryMethod;
  int quantity = 1;
  bool showMoreDescription = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    // Fetch user but don't block viewing - allow browsing without login
    fetchCurrentUser();

    // Initialize the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Set system UI style
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchCurrentUser() async {
    final userProvider = Provider.of<CustomUserProvider>(context, listen: false);
    try {
      await userProvider.fetchUserDetails();
      setState(() {
        currentUser = userProvider.user;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching user data: $e";
        isLoading = false;
      });
    }
  }

  void _navigateToEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(),
      ),
    );
  }

  Future<void> _shareProduct() async {
    final product = widget.product;
    final store = widget.store;
    final String shareMessage = '''
Check out ${product.name} at ${store.name} on Zing!

Price: \u20B9${product.price.toStringAsFixed(2)}
${product.description}

Download Zing app to order now!
https://play.google.com/store/apps/details?id=com.zing.app
''';

    try {
      await Share.share(
        shareMessage,
        subject: 'Check out ${product.name} on Zing!',
      );
    } catch (e) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not share product'),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  // Show login dialog when user tries to perform account-based actions
  Future<bool> _showLoginDialog(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.login_rounded,
                color: cs.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                'Login Required',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            'You need to be logged in to add items to cart and place orders. Would you like to login now?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(context, true);
                // Navigate to login screen
                Navigator.pushNamed(context, '/login');
              },
              child: Text(
                'Login',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _increaseQuantity() {
    // Never let the customer pick more than the store has in stock.
    if (quantity >= widget.product.quantity) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${widget.product.quantity} in stock'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    setState(() {
      quantity++;
    });
    HapticFeedback.lightImpact();
  }

  void _decreaseQuantity() {
    if (quantity > 1) {
      setState(() {
        quantity--;
      });
      HapticFeedback.lightImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);

    return Scaffold(
      extendBody: true,
      body: CustomScrollView(
        slivers: [
          _buildHeroBar(),
          SliverToBoxAdapter(child: _buildProductHeader()),
          SliverToBoxAdapter(child: _buildQuantitySelector()),
          SliverToBoxAdapter(child: _buildDescription()),
          SliverToBoxAdapter(child: _buildStoreInfo()),
          SliverToBoxAdapter(child: _buildDeliveryOptions()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildRelatedProducts(),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 120)),
        ],
      ),
      bottomNavigationBar: _buildActionButtons(cart, orderProvider),
    );
  }

  /// Square product photo that stretches on pull-down and collapses into a
  /// frosted bar with the product name.
  Widget _buildHeroBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final topInset = MediaQuery.paddingOf(context).top;
    const toolbar = 48.0;
    final expandedHeight = width * 0.95;

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final collapsed = constraints.scrollOffset > expandedHeight - toolbar - 40;
        return SliverAppBar(
          pinned: true,
          stretch: true,
          expandedHeight: expandedHeight,
          toolbarHeight: toolbar,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          systemOverlayStyle: theme.brightness == Brightness.dark
              ? SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent)
              : SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent),
          leadingWidth: 60,
          leading: Center(
            child: _GlassIconButton(
              icon: CupertinoIcons.chevron_back,
              plain: collapsed,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ),
          centerTitle: true,
          title: AnimatedOpacity(
            opacity: collapsed ? 1 : 0,
            duration: ZingMotion.fast,
            child: Text(widget.product.name, style: ZingType.headline(cs.onSurface)),
          ),
          actions: [
            _GlassIconButton(icon: CupertinoIcons.share, plain: collapsed, onTap: _shareProduct),
            const SizedBox(width: 12),
          ],
          flexibleSpace: LayoutBuilder(
            builder: (context, c) {
              final minH = toolbar + topInset;
              final t = ((c.maxHeight - minH) / (expandedHeight + topInset - minH)).clamp(0.0, 1.0);
              final glass = ((0.25 - t) / 0.25).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    stretchModes: const [StretchMode.zoomBackground],
                    background: _buildProductImage(),
                  ),
                  if (glass > 0)
                    IgnorePointer(
                      child: Opacity(
                        opacity: glass,
                        child: ZingGlass(
                          color: theme.scaffoldBackgroundColor,
                          opacity: 0.82,
                          border: Border(
                            bottom: BorderSide(color: cs.outline.withValues(alpha: 0.5), width: 0.5),
                          ),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductImage() {
    final cs = Theme.of(context).colorScheme;
    final product = widget.product;
    final hasDiscount = product.discount != null && product.discount! > 0;
    final fallback = Container(
      color: cs.surfaceContainerHighest,
      child: Icon(CupertinoIcons.photo, color: cs.onSurfaceVariant, size: 56),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: 'product-${product.id}',
          child: (product.imageUrl ?? '').isEmpty
              ? fallback
              : CachedNetworkImage(
                  imageUrl: product.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => ColoredBox(color: cs.surfaceContainerHighest),
                  errorWidget: (_, __, ___) => fallback,
                ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x40000000), Color(0x00000000)],
              stops: [0, 0.3],
            ),
          ),
        ),
        if (hasDiscount)
          Positioned(
            left: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: ZingColors.secondary,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '${product.discount!.toStringAsFixed(0)}% OFF',
                style: ZingType.style(13, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  /// "Sold by" row that leads back to the store.
  Widget _buildStoreInfo() {
    return ZingGroupedSection(
      header: 'Sold by',
      children: [
        ZingListRow(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 36,
              height: 36,
              child: widget.store.imageUrl.isEmpty
                  ? const ZingIconTile(icon: CupertinoIcons.bag_fill, color: ZingColors.primary, size: 36)
                  : CachedNetworkImage(imageUrl: widget.store.imageUrl, fit: BoxFit.cover),
            ),
          ),
          title: widget.store.name,
          subtitle: widget.store.category,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ],
    );
  }

  Widget _buildProductHeader() {
    final cs = Theme.of(context).colorScheme;
    final product = widget.product;
    final hasDiscount = product.discount != null && product.discount! > 0;

    final (String stockLabel, Color stockColor) = !product.inStock
        ? ('Out of stock', ZingColors.error)
        : product.lowStock
            ? ('Only ${product.quantity} left', ZingColors.warning)
            : ('In stock', ZingColors.success);

    return ZingReveal(
      offset: 16,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(product.name, style: ZingType.title1(cs.onSurface)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  'Rs ${product.effectivePrice.toStringAsFixed(product.effectivePrice % 1 == 0 ? 0 : 2)}',
                  style: ZingType.title2(cs.onSurface),
                ),
                if (hasDiscount) ...[
                  const SizedBox(width: 10),
                  Text(
                    'Rs ${product.price.toStringAsFixed(0)}',
                    style: ZingType.body(cs.onSurfaceVariant)
                        .copyWith(decoration: TextDecoration.lineThrough),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(stockLabel,
                      style: ZingType.style(13, weight: FontWeight.w600, color: stockColor)),
                ),
              ],
            ),
            if (product.rating != null && product.rating! > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(CupertinoIcons.star_fill, size: 14, color: ZingColors.warning),
                  const SizedBox(width: 4),
                  Text(product.rating!.toStringAsFixed(1), style: ZingType.subhead(cs.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuantitySelector() {
    if (!widget.product.inStock) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return ZingGroupedSection(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      children: [
        ZingListRow(
          icon: CupertinoIcons.number,
          iconColor: ZingColors.primary,
          title: 'Quantity',
          trailing: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildQuantityButton(CupertinoIcons.minus, quantity > 1 ? _decreaseQuantity : null),
                SizedBox(
                  width: 36,
                  child: AnimatedSwitcher(
                    duration: ZingMotion.fast,
                    transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                    child: Text(
                      '$quantity',
                      key: ValueKey(quantity),
                      textAlign: TextAlign.center,
                      style: ZingType.headline(cs.onSurface),
                    ),
                  ),
                ),
                _buildQuantityButton(CupertinoIcons.plus,
                    quantity < widget.product.quantity ? _increaseQuantity : null),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback? onPressed) {
    final cs = Theme.of(context).colorScheme;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(40, 34),
      onPressed: onPressed == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onPressed();
            },
      child: Icon(icon, size: 18, color: onPressed == null ? cs.onSurfaceVariant.withValues(alpha: 0.4) : cs.onSurface),
    );
  }

  Widget _buildDescription() {
    final cs = Theme.of(context).colorScheme;
    final description = (widget.product.description ?? '').trim();
    if (description.isEmpty) return const SizedBox.shrink();
    final isLong = description.length > 160;

    return ZingGroupedSection(
      header: 'About this item',
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: ZingMotion.medium,
                curve: ZingMotion.emphasized,
                alignment: Alignment.topCenter,
                child: Text(
                  description,
                  maxLines: isLong && !showMoreDescription ? 4 : null,
                  overflow: isLong && !showMoreDescription ? TextOverflow.ellipsis : null,
                  style: ZingType.body(cs.onSurface).copyWith(height: 1.45),
                ),
              ),
              if (isLong)
                CupertinoButton(
                  padding: const EdgeInsets.only(top: 6),
                  minimumSize: Size.zero,
                  onPressed: () => setState(() => showMoreDescription = !showMoreDescription),
                  child: Text(showMoreDescription ? 'Less' : 'More', style: ZingType.body(cs.primary)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDeliveryOptions() {
    final options = widget.store.deliveryOptions ?? const <String>[];
    if (options.isEmpty) return const SizedBox.shrink();
    return ZingGroupedSection(
      header: 'Delivery',
      children: [
        for (final option in options)
          ZingListRow(
            icon: option.contains('Home Delivery') ? CupertinoIcons.car_detailed : CupertinoIcons.bag_fill,
            iconColor: option.contains('Home Delivery') ? ZingColors.success : ZingColors.warning,
            title: option,
            value: option.contains('Home Delivery')
                ? (widget.store.deliveryCost != null
                    ? 'Rs ${widget.store.deliveryCost!.toStringAsFixed(0)}'
                    : null)
                : 'Free',
          ),
      ],
    );
  }

  Widget _buildRelatedProducts() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Get related products from the same store, excluding the current product
    final relatedProducts = widget.store.products
        .where((product) => product.id != widget.product.id)
        .toList();

    // If there are no related products, don't show this section
    if (relatedProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Limit to 10 products maximum
    final displayProducts = relatedProducts.take(10).toList();

    return FadeInUp(
      duration: const Duration(milliseconds: 500),
      delay: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "You Might Also Like",
            style: theme.textTheme.headlineSmall?.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          // Show actual products from the store
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: displayProducts.length,
              itemBuilder: (context, index) {
                final product = displayProducts[index];
                final effectivePrice = product.discount != null && product.discount! > 0
                    ? (product.price) * (1 - product.discount! / 100)
                    : product.price;

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // Navigate to the product detail screen
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(
                          product: product,
                          store: widget.store,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    width: 150,
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: ZingShadows.soft,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product image
                        ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          child: Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: product.imageUrl ?? '',
                                height: 120,
                                width: 150,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Shimmer.fromColors(
                                  baseColor: cs.outline,
                                  highlightColor: cs.surfaceContainerHighest,
                                  child: Container(
                                    height: 120,
                                    color: cs.surface,
                                  ),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  height: 120,
                                  color: cs.surfaceContainerHighest,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_rounded,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              // Discount badge
                              if (product.discount != null && product.discount! > 0)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: cs.error,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      "${product.discount}% OFF",
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Product info
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (product.discount != null && product.discount! > 0) ...[
                                    Text(
                                      "Rs. ${effectivePrice.toStringAsFixed(2)}",
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: cs.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Rs. ${product.price.toStringAsFixed(0)}",
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                        color: cs.onSurfaceVariant,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                  ] else
                                    Text(
                                      "Rs. ${product.price.toStringAsFixed(2)}",
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: cs.primary,
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
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToCart(CartProvider cart) async {
    HapticFeedback.mediumImpact();
    if (currentUser == null) {
      await _showLoginDialog(context);
      return;
    }

    // Don't let the cart hold more than the store has in stock.
    final alreadyInCart = cart.items
        .where((i) => i.id == widget.product.id)
        .fold<int>(0, (sum, i) => sum + i.quantity);
    if (alreadyInCart + quantity > widget.product.quantity) {
      final left = widget.product.quantity - alreadyInCart;
      showZingToast(
        context,
        left > 0
            ? 'Only $left more can be added (${widget.product.quantity} in stock)'
            : 'You already have all ${widget.product.quantity} in your bag',
        error: true,
      );
      return;
    }

    final cartItem = CartItem(
      id: widget.product.id,
      name: widget.product.name,
      price: widget.product.effectivePrice,
      imageUrl: widget.product.imageUrl,
      storeId: widget.store.id,
      quantity: 1,
    );

    // CartProvider adds one unit per call.
    for (int i = 0; i < quantity; i++) {
      await cart.addItem(cartItem, context);
    }

    if (!mounted) return;
    showZingToast(context, 'Added $quantity × ${widget.product.name} to your bag',
        icon: CupertinoIcons.bag_fill_badge_plus);
  }

  /// Frosted bottom bar: total, Add to Bag and Buy Now.
  Widget _buildActionButtons(CartProvider cart, OrderProvider orderProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final outOfStock = !widget.product.inStock;
    final total = widget.product.effectivePrice * quantity;

    return ZingGlass(
      opacity: 0.8,
      blur: 30,
      color: theme.brightness == Brightness.dark ? const Color(0xFF161618) : const Color(0xFFF9F9F9),
      border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.55), width: 0.5)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(outOfStock ? 'Unavailable' : 'Total',
                        style: ZingType.footnote(cs.onSurfaceVariant)),
                    AnimatedSwitcher(
                      duration: ZingMotion.fast,
                      child: Text(
                        outOfStock ? 'Out of stock' : 'Rs ${total.toStringAsFixed(total % 1 == 0 ? 0 : 2)}',
                        key: ValueKey(total),
                        style: ZingType.title3(outOfStock ? ZingColors.error : cs.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 56,
                child: ZingPressable(
                  onTap: outOfStock ? null : () => _addToCart(cart),
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: outOfStock ? 0.06 : 0.13),
                      borderRadius: BorderRadius.circular(ZingRadius.md),
                    ),
                    child: Icon(CupertinoIcons.bag_badge_plus,
                        color: outOfStock ? cs.onSurfaceVariant : cs.primary, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 150,
                child: ZingButton(
                  label: 'Buy Now',
                  onPressed: outOfStock
                      ? null
                      : () async {
                          HapticFeedback.mediumImpact();
                          if (currentUser == null) {
                            await _showLoginDialog(context);
                            return;
                          }
                          if (!mounted) return;
                          await _showDeliveryMethodDialog(context, currentUser!, orderProvider);
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showDeliveryMethodDialog(
      BuildContext context,
      CustomUser currentUser,
      OrderProvider orderProvider,
      ) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Check if user details are complete
    if (currentUser.name.isEmpty ||
        currentUser.phoneNumber.isEmpty ||
        currentUser.profileImageUrl.isEmpty) {
      // Show an alert dialog to notify the user to update their profile
      await showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Complete Your Profile',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: cs.error,
              ),
            ),
            content: Text(
              'Please update your profile to include your name, phone number, and profile picture before placing an order.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: cs.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close the dialog
                  _navigateToEditProfile(context); // Navigate to profile edit screen
                },
                child: Text(
                  'Update Profile',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          );
        },
      );
      return; // Exit the function to prevent order placement
    }

    // If user details are complete, proceed to show delivery method dialog
    String? selectedMethod = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: cs.surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Method',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you want to receive your order',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),

                // Delivery options
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.store.deliveryOptions!.map((method) {
                      IconData icon;
                      Color color;

                      // Set appropriate icon and color for each type
                      if (method.contains("Home Delivery")) {
                        icon = Icons.home_rounded;
                        color = cs.tertiary;
                      } else if (method.contains("Pickup")) {
                        icon = Icons.store_rounded;
                        color = ZingColors.warning;
                      } else {
                        icon = Icons.local_shipping_rounded;
                        color = cs.primary;
                      }

                      return RadioListTile<String>(
                        activeColor: cs.primary,
                        tileColor: Colors.transparent,
                        selectedTileColor: cs.primary.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        title: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                icon,
                                color: color,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              method.contains("Home Delivery") && widget.store.deliveryCost != null
                                  ? "Home Delivery"
                                  : method,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface,
                              ),
                            ),
                          ],
                        ),
                        subtitle: method.contains("Home Delivery") && widget.store.deliveryCost != null
                            ? Padding(
                          padding: const EdgeInsets.only(left: 44),
                          child: Text(
                            "Delivery fee: Rs. ${widget.store.deliveryCost!.toStringAsFixed(0)}",
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                            : null,
                        value: method,
                        groupValue: selectedDeliveryMethod,
                        onChanged: (String? value) {
                          setState(() {
                            selectedDeliveryMethod = value!;
                          });
                          Navigator.pop(context, value);
                        },
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Cancel button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedMethod != null) {
      setState(() {
        selectedDeliveryMethod = selectedMethod;
      });

      try {
        // Show loading indicator
        if (!context.mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Dialog(
              backgroundColor: cs.surface,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SpinKitPulsingGrid(
                      color: cs.primary,
                      size: 40,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Processing Order...',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );

        // Add quantity
        List<Product> products = [];
        for (int i = 0; i < quantity; i++) {
          products.add(widget.product);
        }

        // Call the updated placeOrder function
        await orderProvider.placeOrder(
          currentUser.id,
          widget.store,
          products,
          widget.product.discount != null && widget.product.discount! > 0
              ? (widget.product.price) * (1 - widget.product.discount! / 100) * quantity
              : widget.product.price * quantity,
          selectedMethod,
          currentUser,
        );

        // Close loading dialog
        if (!context.mounted) return;
        Navigator.pop(context);

        // Stock changed; reload so screens show the new counts.
        if (!context.mounted) return;
        Provider.of<StoreProvider>(context, listen: false).fetchStores();

        // Show success dialog
        _showOrderSuccessDialog();
      } catch (e) {
        // Close loading dialog
        if (!context.mounted) return;
        Navigator.pop(context);

        // Show error
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error placing order: $e"),
          backgroundColor: cs.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ));
      }
    }
  }

  void _showOrderSuccessDialog() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: ZingColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: ZingColors.success,
                    size: 60,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Order Placed Successfully!',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Your order has been placed and will be processed soon.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continue Shopping',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
/// Round frosted button over the product photo; a plain tinted icon once the
/// bar has collapsed.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool plain;
  const _GlassIconButton({required this.icon, required this.onTap, this.plain = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ZingPressable(
      onTap: onTap,
      pressedScale: 0.88,
      child: AnimatedSwitcher(
        duration: ZingMotion.fast,
        child: plain
            ? SizedBox(
                key: const ValueKey('plain'),
                width: 36,
                height: 36,
                child: Icon(icon, color: cs.primary, size: 22),
              )
            : ZingGlass(
                key: const ValueKey('glass'),
                borderRadius: BorderRadius.circular(100),
                color: Colors.white,
                opacity: 0.75,
                blur: 16,
                child: SizedBox(width: 36, height: 36, child: Icon(icon, color: ZingColors.textDark, size: 19)),
              ),
      ),
    );
  }
}
