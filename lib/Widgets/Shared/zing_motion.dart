import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

/// Shared motion tokens so every screen moves the same way.
class ZingMotion {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 560);

  /// The decelerating curve iOS uses for sheets and navigation pushes.
  static const Curve emphasized = Cubic(0.32, 0.72, 0, 1);

  /// A softer ease for fades and colour changes.
  static const Curve standard = Cubic(0.25, 0.1, 0.25, 1);

  /// Snappy spring with a small overshoot — press release, tab icons.
  static final SpringDescription snappy =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.62);

  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);
}

/// Push a screen with the iOS slide transition and edge swipe-back.
Route<T> zingRoute<T>(Widget page, {bool fullscreenDialog = false}) {
  return CupertinoPageRoute<T>(
    builder: (_) => page,
    fullscreenDialog: fullscreenDialog,
  );
}

/// Scroll physics and overscroll for the whole app: bounce everywhere,
/// no Android glow.
class ZingScrollBehavior extends MaterialScrollBehavior {
  const ZingScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) =>
      child;
}

/// Wraps any tappable surface: it shrinks slightly under the finger and
/// springs back on release, the way iOS cards and buttons respond.
class ZingPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final bool haptic;

  const ZingPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.96,
    this.haptic = true,
  });

  @override
  State<ZingPressable> createState() => _ZingPressableState();
}

class _ZingPressableState extends State<ZingPressable> with SingleTickerProviderStateMixin {
  // 0 = resting, 1 = fully pressed. Unbounded so the spring can overshoot.
  late final AnimationController _press = AnimationController.unbounded(vsync: this, value: 0);

  void _down() {
    _press.animateTo(1, duration: const Duration(milliseconds: 110), curve: Curves.easeOut);
  }

  void _up() {
    _press.animateWith(SpringSimulation(ZingMotion.snappy, _press.value, 0, 0));
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _down() : null,
      onTapUp: enabled ? (_) => _up() : null,
      onTapCancel: enabled ? _up : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, child) {
          final scale = 1 - (1 - widget.pressedScale) * _press.value;
          return Transform.scale(scale: scale, child: child);
        },
        child: widget.child,
      ),
    );
  }
}

/// Reveals its child the first time it scrolls into view: it rises, fades
/// in and settles to full size. Works inside vertical and horizontal lists.
class ZingReveal extends StatefulWidget {
  final Widget child;

  /// Extra wait after becoming visible; use `index * 60ms` to stagger rows.
  final Duration delay;

  /// Distance travelled while revealing, in logical pixels.
  final double offset;
  final Axis axis;

  const ZingReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 28,
    this.axis = Axis.vertical,
  });

  @override
  State<ZingReveal> createState() => _ZingRevealState();
}

class _ZingRevealState extends State<ZingReveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: ZingMotion.slow);
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: ZingMotion.emphasized);

  final List<ScrollPosition> _positions = [];
  bool _triggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_triggered) return;
    if (ZingMotion.reduced(context)) {
      _triggered = true;
      _controller.value = 1;
      return;
    }
    _detach();
    // Listen to every enclosing scrollable so a card inside a horizontal
    // row still reveals when the page scrolls vertically.
    ScrollableState? scrollable = Scrollable.maybeOf(context);
    while (scrollable != null) {
      _positions.add(scrollable.position..addListener(_check));
      scrollable = Scrollable.maybeOf(scrollable.context);
    }
    _checkOverFrames(12);
  }

  // Content often appears while data is still settling (images, slivers
  // above it growing), so look again for a few frames before relying on
  // scroll events alone.
  void _checkOverFrames(int frames) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _triggered) return;
      _check();
      if (!_triggered && frames > 1) _checkOverFrames(frames - 1);
    });
    // Post-frame callbacks only run when a frame is drawn; ask for one.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _detach() {
    for (final position in _positions) {
      position.removeListener(_check);
    }
    _positions.clear();
  }

  void _check() {
    if (_triggered || !mounted) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final screen = MediaQuery.sizeOf(context);
    final topLeft = box.localToGlobal(Offset.zero);
    final visible = topLeft.dy < screen.height * 0.97 &&
        topLeft.dy + box.size.height > 0 &&
        topLeft.dx < screen.width * 0.99 &&
        topLeft.dx + box.size.width > 0;
    if (!visible) return;
    _triggered = true;
    _detach();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _detach();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        final shift = (1 - t) * widget.offset;
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: widget.axis == Axis.vertical ? Offset(0, shift) : Offset(shift, 0),
            child: Transform.scale(scale: 0.97 + 0.03 * t, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Frosted translucent material — the blur behind iOS bars and sheets.
class ZingGlass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  /// How opaque the tint is. 0 shows only the blur, 1 is a solid surface.
  final double opacity;
  final Color? color;
  final Border? border;

  const ZingGlass({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.blur = 24,
    this.opacity = 0.78,
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.surface;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: border,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// An image that drifts more slowly than the card holding it as the list
/// scrolls, giving the card depth. Place inside a clipped box.
///
/// [extent] is how far the image may travel, as a fraction of the card
/// height; the image is drawn that much taller than the card.
class ZingParallax extends StatelessWidget {
  final Widget child;
  final double extent;
  final Axis axis;

  const ZingParallax({super.key, required this.child, this.extent = 0.28, this.axis = Axis.vertical});

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context, axis: axis);
    if (scrollable == null || ZingMotion.reduced(context)) return child;
    final key = GlobalKey();
    return Flow(
      clipBehavior: Clip.hardEdge,
      delegate: _ParallaxDelegate(
        scrollable: scrollable,
        itemContext: context,
        childKey: key,
        extent: extent,
        axis: axis,
      ),
      children: [KeyedSubtree(key: key, child: child)],
    );
  }
}

class _ParallaxDelegate extends FlowDelegate {
  final ScrollableState scrollable;
  final BuildContext itemContext;
  final GlobalKey childKey;
  final double extent;
  final Axis axis;

  _ParallaxDelegate({
    required this.scrollable,
    required this.itemContext,
    required this.childKey,
    required this.extent,
    required this.axis,
  }) : super(repaint: scrollable.position);

  bool get _vertical => axis == Axis.vertical;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) {
    // Oversize the image along the scroll axis so it has room to move.
    return _vertical
        ? BoxConstraints.tightFor(
            width: constraints.maxWidth, height: constraints.maxHeight * (1 + extent))
        : BoxConstraints.tightFor(
            width: constraints.maxWidth * (1 + extent), height: constraints.maxHeight);
  }

  @override
  void paintChildren(FlowPaintingContext context) {
    final viewport = scrollable.context.findRenderObject();
    final item = itemContext.findRenderObject();
    if (viewport is! RenderBox || item is! RenderBox || !item.attached || !viewport.attached) {
      context.paintChild(0);
      return;
    }
    final itemOffset = item.localToGlobal(item.size.centerLeft(Offset.zero), ancestor: viewport);
    // -1 when the card is at the leading edge of the viewport, +1 at the trailing edge.
    final fraction = _vertical
        ? (itemOffset.dy / viewport.size.height).clamp(0.0, 1.0)
        : ((itemOffset.dx + item.size.width / 2) / viewport.size.width).clamp(0.0, 1.0);
    final align = fraction * 2 - 1;
    final childSize = context.getChildSize(0) ?? Size.zero;
    final travel = _vertical
        ? childSize.height - context.size.height
        : childSize.width - context.size.width;
    final shift = -travel / 2 - align * travel / 2;
    context.paintChild(
      0,
      transform: _vertical
          ? Matrix4.translationValues(0, shift, 0)
          : Matrix4.translationValues(shift, 0, 0),
    );
  }

  @override
  bool shouldRepaint(_ParallaxDelegate old) =>
      scrollable != old.scrollable || itemContext != old.itemContext || extent != old.extent;
}

/// A paged carousel where off-centre pages shrink and dim, and the centred
/// page sits forward. Auto-advances until the user touches it.
class ZingDepthCarousel extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final double viewportFraction;
  final Duration? autoPlay;

  const ZingDepthCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.viewportFraction = 0.86,
    this.autoPlay = const Duration(seconds: 5),
  });

  @override
  State<ZingDepthCarousel> createState() => _ZingDepthCarouselState();
}

class _ZingDepthCarouselState extends State<ZingDepthCarousel> {
  late final PageController _controller =
      PageController(viewportFraction: widget.viewportFraction);
  int _page = 0;
  bool _userHolding = false;

  @override
  void initState() {
    super.initState();
    _scheduleNext();
  }

  void _scheduleNext() {
    final interval = widget.autoPlay;
    if (interval == null || widget.itemCount < 2) return;
    Future.delayed(interval, () {
      if (!mounted) return;
      if (!_userHolding && _controller.hasClients && TickerMode.valuesOf(context).enabled) {
        final next = (_page + 1) % widget.itemCount;
        _controller.animateToPage(next, duration: const Duration(milliseconds: 700), curve: ZingMotion.emphasized);
      }
      _scheduleNext();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: Listener(
            onPointerDown: (_) => _userHolding = true,
            onPointerUp: (_) => _userHolding = false,
            onPointerCancel: (_) => _userHolding = false,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.itemCount,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _page = i);
              },
              itemBuilder: (context, index) => AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  double delta = 0;
                  if (_controller.hasClients && _controller.position.haveDimensions) {
                    delta = (_controller.page! - index).clamp(-1.0, 1.0);
                  } else {
                    delta = (_page - index).toDouble().clamp(-1.0, 1.0);
                  }
                  final distance = delta.abs();
                  return Opacity(
                    opacity: 1 - distance * 0.35,
                    child: Transform.scale(
                      scale: 1 - distance * 0.08,
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: widget.itemBuilder(context, index),
                ),
              ),
            ),
          ),
        ),
        if (widget.itemCount > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.itemCount; i++)
                AnimatedContainer(
                  duration: ZingMotion.medium,
                  curve: ZingMotion.emphasized,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
