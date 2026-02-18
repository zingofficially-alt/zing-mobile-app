import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zing/Service/ThemeProvider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _backgroundAnimationController;
  late final AnimationController _contentAnimationController;

  int _currentPage = 0;
  bool _isLastPage = false;

  // Animated background positions
  final List<Alignment> _backgroundAlignments = [
    const Alignment(-0.8, -0.8),
    const Alignment(0.8, -0.8),
    const Alignment(-0.8, 0.8),
  ];

  // Onboarding content
  final List<OnboardingContent> _pages = [
    OnboardingContent(
      title: 'Discover Exclusive Deals',
      description: 'Find your favorite meals at the best prices with exclusive deals tailored just for you.',
      imagePath: 'assets/images/illustration1.png',
      primaryColor: const Color(0xFF5271FF),
      secondaryColor: const Color(0xFF91A5FF),
      iconData: Icons.local_offer_rounded,
    ),
    OnboardingContent(
      title: 'Real-Time Order Tracking',
      description: 'Follow your order journey in real-time with live updates and accurate delivery estimates.',
      imagePath: 'assets/images/illustration2.png',
      primaryColor: const Color(0xFF32B67A),
      secondaryColor: const Color(0xFF7EDDB2),
      iconData: Icons.location_on_rounded,
    ),
    OnboardingContent(
      title: 'Lightning Fast Delivery',
      description: 'Enjoy quick delivery for all your favorites. Your food arrives hot and fresh, every time.',
      imagePath: 'assets/images/illustration3.png',
      primaryColor: const Color(0xFFFF7D54),
      secondaryColor: const Color(0xFFFFB299),
      iconData: Icons.delivery_dining_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Create animation controllers
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _contentAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Initial animations
    _backgroundAnimationController.forward();
    _contentAnimationController.forward();

    // Listen for page changes
    _pageController.addListener(_handlePageChange);

    // Set up fullscreen immersive mode
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: [SystemUiOverlay.top],
    );
  }

  void _handlePageChange() {
    final int newPage = _pageController.page!.round();
    if (newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
        _isLastPage = _currentPage == _pages.length - 1;
      });

      // Reset and play animations
      _backgroundAnimationController.reset();
      _contentAnimationController.reset();
      _backgroundAnimationController.forward();
      _contentAnimationController.forward();
    }
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _navigateToApp();
    }
  }

  void _navigateToApp() {
    // Show a transition animation before navigating
    _contentAnimationController.reverse().then((_) {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  void _skipOnboarding() {
    _navigateToApp();
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    _backgroundAnimationController.dispose();
    _contentAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final OnboardingContent currentContent = _pages[_currentPage];
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(
        children: [
          // Animated background blobs
          AnimatedBuilder(
            animation: _backgroundAnimationController,
            builder: (context, _) {
              final double animValue = _backgroundAnimationController.value;
              return Stack(
                children: [
                  // Primary blob
                  Positioned(
                    top: -size.height * 0.15,
                    right: -size.width * 0.4,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.6, end: 1.0),
                      duration: const Duration(milliseconds: 1500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: child,
                        );
                      },
                      child: _buildBlob(
                        size: size.width * 0.9,
                        color: currentContent.primaryColor.withOpacity(0.15),
                      ),
                    ),
                  ),

                  // Secondary blob
                  Positioned(
                    bottom: -size.height * 0.1,
                    left: -size.width * 0.3,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutQuint,
                      transform: Matrix4.translationValues(
                        0,
                        30 * (1 - animValue),
                        0,
                      ),
                      child: _buildBlob(
                        size: size.width * 0.7,
                        color: currentContent.secondaryColor.withOpacity(0.15),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top bar with progress indicator and skip button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Progress indicator
                      Expanded(
                        child: Row(
                          children: List.generate(
                            _pages.length,
                                (index) => Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 400),
                                margin: const EdgeInsets.only(right: 4),
                                height: 4,
                                decoration: BoxDecoration(
                                  color: index <= _currentPage
                                      ? currentContent.primaryColor
                                      : cs.outlineVariant,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Skip button
                      if (!_isLastPage)
                        TextButton(
                          onPressed: _skipOnboarding,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),

                // Main content area with PageView
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return _buildPage(context, _pages[index]);
                    },
                  ),
                ),

                // Bottom action area
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Main action button
                      AnimatedBuilder(
                        animation: _contentAnimationController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(
                              0,
                              20 * (1 - _contentAnimationController.value),
                            ),
                            child: Opacity(
                              opacity: _contentAnimationController.value,
                              child: child,
                            ),
                          );
                        },
                        child: _GlassButton(
                          onPressed: _nextPage,
                          color: currentContent.primaryColor,
                          icon: _isLastPage
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          text: _isLastPage ? 'Get Started' : 'Continue',
                        ),
                      ),

                      // Alternative action
                      if (_isLastPage)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 400),
                            opacity: _isLastPage ? 1.0 : 0.0,
                            child: GestureDetector(
                              onTap: () =>
                                  Navigator.pushReplacementNamed(context, '/login'),
                              child: RichText(
                                text: TextSpan(
                                  text: 'Already have an account? ',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 14,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Log In',
                                      style: TextStyle(
                                        color: currentContent.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(BuildContext context, OnboardingContent content) {
    return AnimatedBuilder(
      animation: _contentAnimationController,
      builder: (context, _) {
        final double animValue = _contentAnimationController.value;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Feature icon with circular background
              Transform.translate(
                offset: Offset(0, 30 * (1 - animValue)),
                child: Opacity(
                  opacity: animValue,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: content.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      content.iconData,
                      color: content.primaryColor,
                      size: 32,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Main image
              Expanded(
                child: Hero(
                  tag: content.imagePath,
                  child: Transform.translate(
                    offset: Offset(0, 40 * (1 - animValue)),
                    child: Opacity(
                      opacity: animValue,
                      child: _AnimatedImage(
                        imagePath: content.imagePath,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Title with animated highlight
              Transform.translate(
                offset: Offset(0, 20 * (1 - animValue)),
                child: Opacity(
                  opacity: animValue,
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      text: content.title.split(' ')[0] + ' ',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.black.withOpacity(0.8),
                        height: 1.2,
                      ),
                      children: [
                        TextSpan(
                          text: content.title.substring(
                            content.title.indexOf(' ') + 1,
                          ),
                          style: TextStyle(
                            color: content.primaryColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Description text
              Transform.translate(
                offset: Offset(0, 20 * (1 - animValue)),
                child: Opacity(
                  opacity: animValue,
                  child: Text(
                    content.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBlob({required double size, required Color color}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size),
      ),
    );
  }
}

// Animated image with floating effect
class _AnimatedImage extends StatefulWidget {
  final String imagePath;

  const _AnimatedImage({
    Key? key,
    required this.imagePath,
  }) : super(key: key);

  @override
  State<_AnimatedImage> createState() => _AnimatedImageState();
}

class _AnimatedImageState extends State<_AnimatedImage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: Image.asset(
        widget.imagePath,
        fit: BoxFit.contain,
      ),
    );
  }
}

// Glass-morphism style button
class _GlassButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Color color;
  final IconData icon;
  final String text;

  const _GlassButton({
    Key? key,
    required this.onPressed,
    required this.color,
    required this.icon,
    required this.text,
  }) : super(key: key);

  @override
  State<_GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<_GlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        height: 56,
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              widget.color,
              Color.lerp(widget.color, Colors.white, 0.2)!,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.icon,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Data model for onboarding content
class OnboardingContent {
  final String title;
  final String description;
  final String imagePath;
  final Color primaryColor;
  final Color secondaryColor;
  final IconData iconData;

  OnboardingContent({
    required this.title,
    required this.description,
    required this.imagePath,
    required this.primaryColor,
    required this.secondaryColor,
    required this.iconData,
  });
}