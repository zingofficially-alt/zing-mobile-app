import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Service/StoreProvider.dart';
import '../../Service/ThemeProvider.dart';
import '../../screen/StoreManagement/EditStoreScreen.dart';

class AddStoreCard extends StatefulWidget {
  const AddStoreCard({Key? key}) : super(key: key);

  @override
  State<AddStoreCard> createState() => _AddStoreCardState();
}

class _AddStoreCardState extends State<AddStoreCard>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _hoverController;
  late AnimationController _iconController;
  late AnimationController _shimmerController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _iconRotationAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _iconController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _elevationAnimation = Tween<double>(
      begin: 6.0,
      end: 16.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOutCubic,
    ));

    _iconRotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.elasticOut,
    ));

    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Start subtle shimmer animation
    _shimmerController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _iconController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _handleHoverEnter() {
    setState(() => _isHovered = true);
    _hoverController.forward();
    _iconController.forward();
  }

  void _handleHoverExit() {
    setState(() => _isHovered = false);
    _hoverController.reverse();
    _iconController.reverse();
  }

  void _handleTapDown() {
    setState(() => _isPressed = true);
  }

  void _handleTapUp() {
    setState(() => _isPressed = false);
  }

  Future<void> _handleAddStore() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);

    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddEditStoreDialog(
              refreshStoreData: () {
                storeProvider.fetchStores();
              },
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    if (result == true) {
      storeProvider.fetchStores();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return SafeArea(
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_hoverController, _iconController, _shimmerController]),
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => _handleHoverEnter(),
                onExit: (_) => _handleHoverExit(),
                child: GestureDetector(
                  onTapDown: (_) => _handleTapDown(),
                  onTapUp: (_) => _handleTapUp(),
                  onTapCancel: () => _handleTapUp(),
                  onTap: _handleAddStore,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: isSmallScreen ? screenWidth * 0.9 : 320,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _isHovered
                            ? [
                          cs.surface,
                          cs.surfaceContainerHighest,
                        ]
                            : [
                          cs.surface,
                          cs.surfaceContainerHighest,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: cs.primary.withOpacity(
                            _isHovered ? 0.15 : 0.08,
                          ),
                          blurRadius: _elevationAnimation.value,
                          offset: Offset(0, _elevationAnimation.value / 3),
                          spreadRadius: _isHovered ? 2 : 0,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(
                        color: _isHovered
                            ? cs.primary.withOpacity(0.2)
                            : cs.outlineVariant,
                        width: _isHovered ? 1.5 : 1,
                      ),
                    ),
                    padding: EdgeInsets.all(isSmallScreen ? 20 : 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated Icon Container
                        Transform.rotate(
                          angle: _iconRotationAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  cs.primary,
                                  cs.tertiary,
                                ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                // Shimmer effect
                                AnimatedBuilder(
                                  animation: _shimmerAnimation,
                                  builder: (context, child) {
                                    return Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment(-1.0 + _shimmerAnimation.value, 0.0),
                                          end: Alignment(1.0 + _shimmerAnimation.value, 0.0),
                                          colors: [
                                            Colors.transparent,
                                            Colors.white.withOpacity(0.1),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                Icon(
                                  Icons.store_rounded,
                                  size: isSmallScreen ? 40 : 48,
                                  color: cs.onPrimary,
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 20 : 24),

                        // Title with gradient text effect
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: [
                              cs.onSurface,
                              cs.onSurfaceVariant,
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'Start Your Business',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 22 : 26,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 8 : 12),

                        // Description
                        Text(
                          'Create your store and start selling today.\nBuild your empire, one product at a time.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                            letterSpacing: 0.1,
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 24 : 32),

                        // Enhanced Action Button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          transform: Matrix4.identity()
                            ..scale(_isPressed ? 0.98 : 1.0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _isHovered
                                    ? [
                                  cs.primary.withOpacity(0.9),
                                  cs.tertiary,
                                ]
                                    : [
                                  cs.primary,
                                  cs.tertiary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: cs.primary.withOpacity(0.4),
                                  blurRadius: _isHovered ? 12 : 8,
                                  offset: Offset(0, _isHovered ? 6 : 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _handleAddStore,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 20 : 28,
                                    vertical: isSmallScreen ? 16 : 20,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.add_business_rounded,
                                          color: cs.onPrimary,
                                          size: isSmallScreen ? 18 : 20,
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 10 : 12),
                                      Text(
                                        'Create Store',
                                        style: TextStyle(
                                          color: cs.onPrimary,
                                          fontSize: isSmallScreen ? 16 : 18,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      SizedBox(width: isSmallScreen ? 8 : 10),
                                      AnimatedRotation(
                                        turns: _isHovered ? 0.125 : 0,
                                        duration: const Duration(milliseconds: 300),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          color: cs.onPrimary,
                                          size: isSmallScreen ? 16 : 18,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// Usage function for backward compatibility
Widget buildAddStoreButton(BuildContext context) {
  return const AddStoreCard();
}
