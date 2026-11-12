import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:provider/provider.dart';
import 'package:zing/Cart/CartProvider.dart';
import 'package:zing/Modal/CoustomUser.dart';
import 'package:zing/Service/OrderProvider.dart';
import 'package:animate_do/animate_do.dart';
import 'package:zing/screen/UserScreens/EditeUser.dart';
import '../../Service/CoustomUserProvider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:shimmer/shimmer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zing/Service/ThemeProvider.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final Store store;

  ProductDetailScreen({required this.product, required this.store});

  @override
  _ProductDetailScreenState createState() => _ProductDetailScreenState();
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
            content: Text('Could not share product'),
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final cart = Provider.of<CartProvider>(context);
    final orderProvider = Provider.of<OrderProvider>(context, listen: false);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: cs.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Main content - Always show products, login not required for browsing
          SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                _buildProductImage(screenHeight),

                // Product Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store name
                      _buildStoreInfo(),
                      SizedBox(height: 16),

                      // Product name and price
                      _buildProductHeader(),
                      SizedBox(height: 24),

                      // Quantity selector
                      _buildQuantitySelector(),
                      SizedBox(height: 24),

                      // Description
                      _buildDescription(),
                      SizedBox(height: 24),

                      // Delivery options
                      _buildDeliveryOptions(),
                      SizedBox(height: 24),

                      // Related products
                      _buildRelatedProducts(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildActionButtons(cart, orderProvider),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.pop(context);
        },
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            Icons.arrow_back_rounded,
            color: cs.onSurface,
          ),
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();

            // Check if user is logged in
            if (currentUser == null) {
              await _showLoginDialog(context);
              return;
            }

            // Add to favorites logic
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Added to favorites!",
                ),
                backgroundColor: cs.primary,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.favorite_border_rounded,
              color: cs.onSurface,
            ),
          ),
        ),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _shareProduct();
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cs.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.share_rounded,
              color: cs.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 70,
            color: cs.error.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            "Oops! Something went wrong",
            style: theme.textTheme.headlineSmall?.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              errorMessage ?? "An unknown error occurred",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                isLoading = true;
                errorMessage = null;
              });
              fetchCurrentUser();
            },
            icon: Icon(Icons.refresh_rounded),
            label: Text(
              "Try Again",
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoUserState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_rounded,
            size: 70,
            color: cs.onSurfaceVariant.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            "User Not Found",
            style: theme.textTheme.headlineSmall?.copyWith(
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Please sign in to view product details and place orders",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to login screen
            },
            icon: Icon(Icons.login_rounded),
            label: Text(
              "Sign In",
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductImage(double screenHeight) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Hero(
      tag: widget.product.imageUrl ?? '',
      child: Container(
        height: screenHeight * 0.45,
        width: double.infinity,
        child: Stack(
          children: [
            // Product image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                child: CachedNetworkImage(
                  imageUrl: widget.product.imageUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Shimmer.fromColors(
                    baseColor: cs.outline,
                    highlightColor: cs.surfaceContainerHighest,
                    child: Container(
                      color: cs.surface,
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: cs.surfaceContainerHighest,
                    child: Icon(
                      Icons.image_not_supported_rounded,
                      color: cs.onSurfaceVariant,
                      size: 50,
                    ),
                  ),
                ),
              ),
            ),

            // Gradient overlay at bottom for better text contrast
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
              ),
            ),

            // Availability badge - Check both isAvailable and quantity
            if (widget.product.isAvailable && widget.product.quantity > 0)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ZingColors.success,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: ZingColors.success.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: cs.onPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "In Stock (${widget.product.quantity})",
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.error,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: cs.error.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cancel_rounded,
                        color: cs.onPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Out of Stock",
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Discount badge (if applicable)
            if (widget.product.discount != null && widget.product.discount! > 0)
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.error,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [
                      BoxShadow(
                        color: cs.error.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        color: cs.onPrimary,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "${widget.product.discount}% OFF",
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
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

  Widget _buildStoreInfo() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: cs.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              Icons.store_rounded,
              color: cs.primary,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sold by",
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            Text(
              widget.store.name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const Spacer(),
        if (widget.product.rating != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: ZingColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ZingColors.warning.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.star_rounded,
                  color: ZingColors.warning,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  "${widget.product.rating!}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildProductHeader() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product name
        FadeInLeft(
          duration: Duration(milliseconds: 500),
          child: Text(
            widget.product.name,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Price
        FadeInRight(
          duration: Duration(milliseconds: 500),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // If there's a discount, show the reduced price
              if (widget.product.discount != null && widget.product.discount! > 0) ...[
                // Calculate discounted price
                Text(
                  "Rs. ${((widget.product.price) * (1 - widget.product.discount! / 100)).toStringAsFixed(2)}",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "Rs. ${widget.product.price.toStringAsFixed(2)}",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: cs.onSurfaceVariant,
                  ),
                ),
              ] else
                Text(
                  "Rs. ${widget.product.price.toStringAsFixed(2)}",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FadeInUp(
      duration: Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ZingShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildQuantityButton(Icons.remove_rounded, _decreaseQuantity),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                quantity.toString(),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.onSurface,
                ),
              ),
            ),
            _buildQuantityButton(Icons.add_rounded, _increaseQuantity),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityButton(IconData icon, VoidCallback onPressed) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          color: cs.primary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildDescription() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Use a default description if none is provided
    final description = widget.product.description ?? "No product description available. This product is provided by ${widget.store.name}.";

    // Determine if the description is long enough to need a "Show More" button
    final isLongDescription = description.length > 100;

    return FadeInUp(
      duration: Duration(milliseconds: 500),
      delay: Duration(milliseconds: 100),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ZingShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description_rounded,
                  color: cs.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Product Description",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isLongDescription && !showMoreDescription
                  ? description.substring(0, 100) + "..."
                  : description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),

            // Show More button for long descriptions
            if (isLongDescription)
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    showMoreDescription = !showMoreDescription;
                  });
                },
                style: TextButton.styleFrom(
                  foregroundColor: cs.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  showMoreDescription ? "Show Less" : "Show More",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryOptions() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Check if delivery options exist
    if (widget.store.deliveryOptions == null || widget.store.deliveryOptions!.isEmpty) {
      return SizedBox.shrink();
    }

    return FadeInUp(
      duration: Duration(milliseconds: 500),
      delay: Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ZingShadows.soft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_shipping_rounded,
                  color: cs.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  "Delivery Options",
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List of delivery options
            Column(
              children: widget.store.deliveryOptions!.map((option) {
                IconData icon;
                Color color;

                // Set appropriate icon and color for each type
                if (option.contains("Home Delivery")) {
                  icon = Icons.home_rounded;
                  color = cs.tertiary;
                } else if (option.contains("Pickup")) {
                  icon = Icons.store_rounded;
                  color = ZingColors.warning;
                } else {
                  icon = Icons.local_shipping_rounded;
                  color = cs.primary;
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          option.contains("Home Delivery") && widget.store.deliveryCost != null
                              ? "Home Delivery (Rs. ${widget.store.deliveryCost!.toStringAsFixed(0)})"
                              : option,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
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
      return SizedBox.shrink();
    }

    // Limit to 10 products maximum
    final displayProducts = relatedProducts.take(10).toList();

    return FadeInUp(
      duration: Duration(milliseconds: 500),
      delay: Duration(milliseconds: 300),
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
          Container(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: BouncingScrollPhysics(),
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
                          borderRadius: BorderRadius.only(
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

  Widget _buildActionButtons(CartProvider cart, OrderProvider orderProvider) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bool isOutOfStock = widget.product.quantity <= 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
            spreadRadius: 1,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Total price or Out of Stock message
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isOutOfStock ? "Status" : "Total Price",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                Text(
                  isOutOfStock
                      ? "Out of Stock"
                      : (widget.product.discount != null && widget.product.discount! > 0
                          ? "Rs. ${((widget.product.price) * (1 - widget.product.discount! / 100) * quantity).toStringAsFixed(2)}"
                          : "Rs. ${(widget.product.price * quantity).toStringAsFixed(2)}"),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: isOutOfStock ? cs.error : cs.primary,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Add to cart button
            GestureDetector(
              onTapDown: isOutOfStock ? null : (_) => _animationController.forward(),
              onTapUp: isOutOfStock ? null : (_) => _animationController.reverse(),
              onTapCancel: isOutOfStock ? null : () => _animationController.reverse(),
              onTap: isOutOfStock ? null : () async {
                HapticFeedback.mediumImpact();

                // Check if user is logged in
                if (currentUser == null) {
                  await _showLoginDialog(context);
                  return;
                }

                // Calculate the effective price (with discount if applicable)
                double effectivePrice = widget.product.discount != null && widget.product.discount! > 0
                    ? (widget.product.price) * (1 - widget.product.discount! / 100)
                    : widget.product.price;

                // Create CartItem from Product
                CartItem cartItem = CartItem(
                  id: widget.product.id,
                  name: widget.product.name,
                  price: effectivePrice,
                  imageUrl: widget.product.imageUrl,
                  storeId: widget.store.id,
                  quantity: 1,
                );

                // Add to cart multiple times based on quantity
                // The CartProvider increments quantity by 1 for each add
                for (int i = 0; i < quantity; i++) {
                  await cart.addItem(cartItem, context);
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      "$quantity ${widget.product.name} added to cart!",
                    ),
                    backgroundColor: cs.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  );
                },
                child: Opacity(
                  opacity: isOutOfStock ? 0.5 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.shopping_cart_rounded,
                          color: cs.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Add to Cart",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Buy now button
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTapDown: isOutOfStock ? null : (_) => _animationController.forward(),
                onTapUp: isOutOfStock ? null : (_) => _animationController.reverse(),
                onTapCancel: isOutOfStock ? null : () => _animationController.reverse(),
                onTap: isOutOfStock ? null : () async {
                  HapticFeedback.mediumImpact();

                  // Check if user is logged in
                  if (currentUser == null) {
                    await _showLoginDialog(context);
                    return;
                  }

                  await _showDeliveryMethodDialog(context, currentUser!, orderProvider);
                },
                child: AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    );
                  },
                  child: Opacity(
                    opacity: isOutOfStock ? 0.5 : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isOutOfStock ? cs.outline : cs.primary,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: (isOutOfStock ? cs.outline : cs.primary).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Buy Now",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
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
                        selectedTileColor: cs.primary.withOpacity(0.05),
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
                                color: color.withOpacity(0.1),
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
        Navigator.pop(context);

        // Show success dialog
        _showOrderSuccessDialog();
      } catch (e) {
        // Close loading dialog
        Navigator.pop(context);

        // Show error
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
                    color: ZingColors.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
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