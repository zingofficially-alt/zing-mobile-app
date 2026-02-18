import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../Modal/CoustomUser.dart';
import '../../Service/ThemeProvider.dart';

class DeliveryOptionsWidget extends StatefulWidget {
  final Store store;

  const DeliveryOptionsWidget({Key? key, required this.store}) : super(key: key);

  @override
  State<DeliveryOptionsWidget> createState() => _DeliveryOptionsWidgetState();
}

class _DeliveryOptionsWidgetState extends State<DeliveryOptionsWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  IconData _getDeliveryIcon(String option) {
    switch (option.toLowerCase()) {
      case 'home delivery':
        return Icons.local_shipping_rounded;
      case 'pickup':
      case 'store pickup':
        return Icons.store_rounded;
      case 'express delivery':
        return Icons.flash_on_rounded;
      case 'drone delivery':
        return Icons.flight_rounded;
      case 'same day delivery':
        return Icons.today_rounded;
      default:
        return Icons.local_shipping_rounded;
    }
  }

  Color _getDeliveryColor(BuildContext context, String option) {
    final cs = Theme.of(context).colorScheme;
    switch (option.toLowerCase()) {
      case 'home delivery':
        return ZingColors.success;
      case 'pickup':
      case 'store pickup':
        return cs.primary;
      case 'express delivery':
        return ZingColors.warning;
      case 'drone delivery':
        return cs.tertiary;
      case 'same day delivery':
        return cs.error;
      default:
        return ZingColors.success;
    }
  }

  String _getDeliveryDescription(String option) {
    switch (option.toLowerCase()) {
      case 'home delivery':
        return 'Direct to your doorstep';
      case 'pickup':
      case 'store pickup':
        return 'Collect from store';
      case 'express delivery':
        return 'Fast delivery service';
      case 'drone delivery':
        return 'Delivered by drone';
      case 'same day delivery':
        return 'Same day service';
      default:
        return 'Standard delivery';
    }
  }

  Widget _buildDeliveryOptionCard(String option, int index) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final color = _getDeliveryColor(context, option);
    final icon = _getDeliveryIcon(option);
    final description = _getDeliveryDescription(option);
    final isHomeDelivery = option.toLowerCase() == 'home delivery';
    final hasDeliveryCost = isHomeDelivery && widget.store.deliveryCost != null;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Container(
              margin: EdgeInsets.only(bottom: index < widget.store.deliveryOptions!.length - 1 ? 12 : 0),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: color.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withOpacity(0.05),
                        color.withOpacity(0.02),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icon Container
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              color,
                              color.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title Row
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface,
                                      letterSpacing: 0.1,
                                    ),
                                  ),
                                ),
                                if (hasDeliveryCost)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: color.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      '\$${widget.store.deliveryCost!.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ),
                              ],
                            ),

                            const SizedBox(height: 4),

                            // Description
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: cs.onSurfaceVariant,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Status Indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (widget.store.deliveryOptions == null || widget.store.deliveryOptions!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: cs.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'No delivery options available',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
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
                      ),
                      child: Icon(
                        Icons.local_shipping_rounded,
                        color: cs.onPrimary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Options',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          '${widget.store.deliveryOptions!.length} option${widget.store.deliveryOptions!.length > 1 ? 's' : ''} available',
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delivery Options List
              ...widget.store.deliveryOptions!.asMap().entries.map(
                    (entry) => _buildDeliveryOptionCard(entry.value, entry.key),
              ).toList(),
            ],
          ),
        );
      },
    );
  }
}

// Usage function for backward compatibility
Widget buildDeliveryOptions(Store store) {
  return DeliveryOptionsWidget(store: store);
}
