import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../Modal/CoustomUser.dart';
import '../../Service/ThemeProvider.dart';
import '../../screen/StoreManagement/EditProduct.dart';

class EnhancedProductGrid extends StatefulWidget {
  final Store userStore;
  final List<Product> products;
  final Function(int)? onProductDeleted;

  const EnhancedProductGrid({
    Key? key,
    required this.userStore,
    required this.products,
    this.onProductDeleted,
  }) : super(key: key);

  @override
  State<EnhancedProductGrid> createState() => _EnhancedProductGridState();
}

class _EnhancedProductGridState extends State<EnhancedProductGrid>
    with TickerProviderStateMixin {
  late AnimationController _staggerController;
  final List<AnimationController> _cardControllers = [];
  final List<Animation<double>> _cardAnimations = [];

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      duration: Duration(milliseconds: 600 + (widget.products.length * 100)),
      vsync: this,
    );

    _initializeCardAnimations();
    _staggerController.forward();
  }

  void _initializeCardAnimations() {
    for (int i = 0; i < widget.products.length; i++) {
      final controller = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );

      final animation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: controller,
        curve: Interval(
          (i * 0.1).clamp(0.0, 1.0),
          ((i * 0.1) + 0.6).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic,
        ),
      ));

      _cardControllers.add(controller);
      _cardAnimations.add(animation);
    }

    _staggerController.addListener(() {
      for (var controller in _cardControllers) {
        controller.value = _staggerController.value;
      }
    });
  }

  @override
  void dispose() {
    _staggerController.dispose();
    for (var controller in _cardControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  int _getCrossAxisCount(double screenWidth) {
    if (screenWidth < 600) return 2;
    if (screenWidth < 900) return 3;
    if (screenWidth < 1200) return 4;
    return 5;
  }

  double _getHorizontalPadding(double screenWidth) {
    if (screenWidth < 600) return 12;
    if (screenWidth < 1200) return 16;
    return 20;
  }

  Future<void> _deleteProduct(Product product, int index) async {
    final confirm = await _showDeleteDialog();
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .delete();

      if (widget.onProductDeleted != null) {
        widget.onProductDeleted!(index);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Product deleted successfully'),
              ],
            ),
            backgroundColor: ZingColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        final cs = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: cs.onError),
                const SizedBox(width: 12),
                Text('Failed to delete: ${error.toString()}'),
              ],
            ),
            backgroundColor: cs.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<bool?> _showDeleteDialog() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.delete_outline,
                color: cs.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Product'),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this product? This action cannot be undone.',
          style: TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(
              foregroundColor: cs.onSurfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _getCrossAxisCount(screenWidth);
    final horizontalPadding = _getHorizontalPadding(screenWidth);

    if (widget.products.isEmpty) {
      return _buildEmptyState();
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: widget.products.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 20,
          crossAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemBuilder: (context, index) {
          if (index >= _cardAnimations.length) return const SizedBox.shrink();

          return AnimatedBuilder(
            animation: _cardAnimations[index],
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, (1 - _cardAnimations[index].value) * 50),
                child: Opacity(
                  opacity: _cardAnimations[index].value,
                  child: _ProductCard(
                    product: widget.products[index],
                    userStore: widget.userStore,
                    onDelete: () => _deleteProduct(widget.products[index], index),
                    screenWidth: screenWidth,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  cs.outlineVariant,
                  cs.onSurfaceVariant,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              color: cs.onPrimary,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Products Yet',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding products to see them here',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatefulWidget {
  final Product product;
  final Store userStore;
  final VoidCallback onDelete;
  final double screenWidth;

  const _ProductCard({
    required this.product,
    required this.userStore,
    required this.onDelete,
    required this.screenWidth,
  });

  @override
  State<_ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<_ProductCard>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _hoverController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.03,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _elevationAnimation = Tween<double>(
      begin: 8.0,
      end: 16.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  void _navigateToEdit() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            EditProductScreen(product: widget.product, storeId: widget.userStore.id!),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final imageUrl = (widget.product.imageUrl != null && widget.product.imageUrl!.isNotEmpty)
        ? widget.product.imageUrl!
        : '';

    return AnimatedBuilder(
      animation: _hoverController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: MouseRegion(
            onEnter: (_) {
              setState(() => _isHovered = true);
              _hoverController.forward();
            },
            onExit: (_) {
              setState(() => _isHovered = false);
              _hoverController.reverse();
            },
            child: GestureDetector(
              onTap: _navigateToEdit,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: _elevationAnimation.value,
                      offset: Offset(0, _elevationAnimation.value / 3),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Container
                      Expanded(
                        flex: 3,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                child: imageUrl.isNotEmpty
                                    ? Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  cs.surfaceContainerHighest,
                                                  cs.outlineVariant,
                                                ],
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: cs.onSurfaceVariant,
                                              size: 40,
                                            ),
                                          );
                                        },
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Shimmer.fromColors(
                                            baseColor: cs.surfaceContainerHighest,
                                            highlightColor: cs.surface,
                                            child: Container(
                                              color: cs.surfaceContainerHighest,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              cs.surfaceContainerHighest,
                                              cs.outlineVariant,
                                            ],
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: cs.onSurfaceVariant,
                                          size: 40,
                                        ),
                                      ),
                              ),
                            ),

                            // Hover Overlay
                            if (_isHovered)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(20),
                                      topRight: Radius.circular(20),
                                    ),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.1),
                                        Colors.black.withOpacity(0.3),
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Content Container
                      Expanded(
                        flex: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Product Name
                              Text(
                                widget.product.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: widget.screenWidth < 600 ? 14 : 16,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),

                              const SizedBox(height: 8),

                              // Price and Quantity
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "RS ${widget.product.price.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontSize: widget.screenWidth < 600 ? 16 : 18,
                                      fontWeight: FontWeight.w700,
                                      color: ZingColors.success,
                                    ),
                                  ),
                                  // Quantity badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: widget.product.quantity > 0
                                          ? ZingColors.success.withOpacity(0.1)
                                          : cs.error.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.product.quantity > 0
                                          ? 'Qty: ${widget.product.quantity}'
                                          : 'Out',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: widget.product.quantity > 0
                                            ? ZingColors.success
                                            : cs.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const Spacer(),

                              // Action Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Edit Button
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          cs.primary,
                                          cs.tertiary,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: cs.primary.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: _navigateToEdit,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.edit_rounded,
                                            color: cs.onPrimary,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Delete Button
                                  Container(
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          cs.error,
                                          cs.error.withOpacity(0.8),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: cs.error.withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(10),
                                        onTap: widget.onDelete,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: Icon(
                                            Icons.delete_rounded,
                                            color: cs.onError,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Usage function for backward compatibility
Widget buildProductGrid(Store userStore, List<Product> products, BuildContext context) {
  return EnhancedProductGrid(
    userStore: userStore,
    products: products,
  );
}
