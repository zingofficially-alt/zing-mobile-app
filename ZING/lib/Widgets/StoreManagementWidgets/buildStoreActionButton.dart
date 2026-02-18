import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../Chat/ChatScreen.dart';
import '../../Chat/ChatsScreen.dart';
import '../../Modal/CoustomUser.dart';
import '../../Service/CoustomUserProvider.dart';
import '../../Service/StoreProvider.dart';
import '../../Service/ThemeProvider.dart';
import '../../screen/StoreManagement/EditStoreScreen.dart';

class EnhancedStoreActions extends StatefulWidget {
  final Store userStore;
  final CustomUser user;

  const EnhancedStoreActions({
    Key? key,
    required this.userStore,
    required this.user,
  }) : super(key: key);

  @override
  State<EnhancedStoreActions> createState() => _EnhancedStoreActionsState();
}

class _EnhancedStoreActionsState extends State<EnhancedStoreActions>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _staggerController;
  late List<AnimationController> _buttonControllers;

  late Animation<double> _fadeAnimation;
  late List<Animation<double>> _buttonAnimations;
  late List<Animation<Offset>> _slideAnimations;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _staggerController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _buttonControllers = List.generate(3, (index) => AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    _buttonAnimations = List.generate(3, (index) =>
        Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            index * 0.2,
            0.6 + (index * 0.2),
            curve: Curves.easeOutBack,
          ),
        ))
    );

    _slideAnimations = List.generate(3, (index) =>
        Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _staggerController,
          curve: Interval(
            index * 0.2,
            0.6 + (index * 0.2),
            curve: Curves.easeOutCubic,
          ),
        ))
    );

    _startAnimations();
  }

  void _startAnimations() async {
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _staggerController.dispose();
    for (var controller in _buttonControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _editStore() async {
    final storeProvider = Provider.of<StoreProvider>(context, listen: false);

    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddEditStoreDialog(
              store: widget.userStore,
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

  Future<void> _deleteStore() async {
    final confirm = await _showDeleteDialog();
    if (confirm != true) return;

    final storeProvider = Provider.of<StoreProvider>(context, listen: false);
    final customUserProvider = Provider.of<CustomUserProvider>(context, listen: false);

    try {
      await storeProvider.deleteStore(widget.userStore.id!, customUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Store deleted successfully'),
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
                Text('Failed to delete store: ${error.toString()}'),
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
      barrierDismissible: false,
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
                Icons.warning_rounded,
                color: cs.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Delete Store'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete this store?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: cs.error.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: cs.error,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This action cannot be undone. All store data will be permanently deleted.',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
            child: const Text('Delete Store'),
          ),
        ],
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            OwnerChatListScreen(store: widget.userStore),
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

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onPressed,
    required int index,
    bool isFullWidth = false,
  }) {
    return AnimatedBuilder(
      animation: Listenable.merge([_buttonAnimations[index], _buttonControllers[index]]),
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimations[index],
          child: FadeTransition(
            opacity: _buttonAnimations[index],
            child: Transform.scale(
              scale: 1.0 - (_buttonControllers[index].value * 0.05),
              child: Container(
                width: isFullWidth ? double.infinity : null,
                margin: EdgeInsets.only(
                  bottom: index < 2 ? 16 : 0,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: onPressed,
                      onTapDown: (_) => _buttonControllers[index].forward(),
                      onTapUp: (_) => _buttonControllers[index].reverse(),
                      onTapCancel: () => _buttonControllers[index].reverse(),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                icon,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isFullWidth)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
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
                      Icons.settings,
                      color: cs.onPrimary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Store Management',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Manage your store settings and interactions',
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

            // Action Buttons
            if (isSmallScreen) ...[
              // Mobile Layout - Stacked
              _buildActionButton(
                title: 'Edit Store',
                subtitle: 'Update store information',
                icon: Icons.edit_rounded,
                gradientColors: [
                  ZingColors.warning,
                  cs.error,
                ],
                onPressed: _editStore,
                index: 0,
                isFullWidth: true,
              ),

              _buildActionButton(
                title: 'Delete Store',
                subtitle: 'Permanently remove store',
                icon: Icons.delete_rounded,
                gradientColors: [
                  cs.error,
                  cs.error.withOpacity(0.8),
                ],
                onPressed: _deleteStore,
                index: 1,
                isFullWidth: true,
              ),

              _buildActionButton(
                title: 'Customer Chat',
                subtitle: 'View and respond to messages',
                icon: Icons.chat_rounded,
                gradientColors: [
                  cs.primary,
                  cs.primary.withOpacity(0.8),
                ],
                onPressed: _openChat,
                index: 2,
                isFullWidth: true,
              ),
            ] else ...[
              // Desktop Layout - Two on top, one below
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      title: 'Edit Store',
                      subtitle: 'Update store information',
                      icon: Icons.edit_rounded,
                      gradientColors: [
                        ZingColors.warning,
                        cs.error,
                      ],
                      onPressed: _editStore,
                      index: 0,
                      isFullWidth: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      title: 'Delete Store',
                      subtitle: 'Permanently remove store',
                      icon: Icons.delete_rounded,
                      gradientColors: [
                        cs.error,
                        cs.error.withOpacity(0.8),
                      ],
                      onPressed: _deleteStore,
                      index: 1,
                      isFullWidth: true,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _buildActionButton(
                title: 'Customer Chat',
                subtitle: 'View and respond to messages',
                icon: Icons.chat_rounded,
                gradientColors: [
                  cs.primary,
                  cs.primary.withOpacity(0.8),
                ],
                onPressed: _openChat,
                index: 2,
                isFullWidth: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Usage function for backward compatibility
Widget buildStoreActions(Store userStore, CustomUser user, BuildContext context) {
  return EnhancedStoreActions(
    userStore: userStore,
    user: user,
  );
}
