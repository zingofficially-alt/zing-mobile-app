import 'package:flutter/material.dart';
import 'dart:math' as math;

/// An enhanced circular progress indicator with customizable appearance and animations
class EnhancedCircularProgress extends StatefulWidget {
  /// Progress value from 0.0 to 1.0
  final double value;

  /// Width of the progress stroke
  final double strokeWidth;

  /// Color for the progress arc (ignored if gradient is provided)
  final Color? color;

  /// Optional gradient to use instead of a solid color
  final Gradient? gradient;

  /// Background circle color
  final Color backgroundColor;

  /// Background opacity (0.0 to 1.0)
  final double backgroundOpacity;

  /// Whether to display percentage text in the center
  final bool showPercentage;

  /// Text style for the percentage text
  final TextStyle? percentageTextStyle;

  /// Whether to add a subtle glow effect to the progress arc
  final bool addGlowEffect;

  /// Glow effect color (defaults to progress color if not specified)
  final Color? glowColor;

  /// Duration of the progress animation
  final Duration animationDuration;

  /// Optional start angle in radians (default: -π/2 which is the top of the circle)
  final double startAngle;

  /// Whether the progress indicator should be clockwise
  final bool clockwise;

  /// Whether to round both ends of the progress arc
  final bool roundCaps;

  /// Optional custom widget to display in the center
  final Widget? centerWidget;

  /// Size of the progress indicator
  final double size;

  /// Optional dash pattern for the progress arc [dashWidth, gapWidth]
  final List<double>? dashPattern;

  const EnhancedCircularProgress({
    Key? key,
    required this.value,
    this.strokeWidth = 10.0,
    this.color,
    this.gradient,
    this.backgroundColor = const Color(0xFFEEEEEE),
    this.backgroundOpacity = 1.0,
    this.showPercentage = false,
    this.percentageTextStyle,
    this.addGlowEffect = false,
    this.glowColor,
    this.animationDuration = const Duration(milliseconds: 500),
    this.startAngle = -math.pi / 2,
    this.clockwise = true,
    this.roundCaps = true,
    this.centerWidget,
    this.size = 100.0,
    this.dashPattern,
  }) : assert(color != null || gradient != null, 'Either color or gradient must be provided'),
        super(key: key);

  @override
  State<EnhancedCircularProgress> createState() => _EnhancedCircularProgressState();
}

class _EnhancedCircularProgressState extends State<EnhancedCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;
  late double _previousValue;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.value;
    _animationController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: widget.value,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void didUpdateWidget(EnhancedCircularProgress oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.value != widget.value) {
      _previousValue = oldWidget.value;
      _progressAnimation = Tween<double>(
        begin: _previousValue,
        end: widget.value,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ));

      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _progressAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Progress circle
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _EnhancedCircleProgressPainter(
                  percentage: _progressAnimation.value,
                  strokeWidth: widget.strokeWidth,
                  color: widget.color ?? Colors.blue,
                  gradient: widget.gradient,
                  backgroundColor: widget.backgroundColor.withOpacity(widget.backgroundOpacity),
                  addGlowEffect: widget.addGlowEffect,
                  glowColor: widget.glowColor ?? widget.color ?? Colors.blue,
                  startAngle: widget.startAngle,
                  clockwise: widget.clockwise,
                  roundCaps: widget.roundCaps,
                  dashPattern: widget.dashPattern,
                ),
              ),

              // Center content
              if (widget.centerWidget != null)
                widget.centerWidget!
              else if (widget.showPercentage)
                Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: widget.percentageTextStyle ??
                      TextStyle(
                        fontSize: widget.size / 5,
                        fontWeight: FontWeight.bold,
                        color: widget.color ?? Colors.blue,
                      ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EnhancedCircleProgressPainter extends CustomPainter {
  final double percentage;
  final double strokeWidth;
  final Color color;
  final Gradient? gradient;
  final Color backgroundColor;
  final bool addGlowEffect;
  final Color glowColor;
  final double startAngle;
  final bool clockwise;
  final bool roundCaps;
  final List<double>? dashPattern;

  _EnhancedCircleProgressPainter({
    required this.percentage,
    required this.strokeWidth,
    required this.color,
    this.gradient,
    required this.backgroundColor,
    required this.addGlowEffect,
    required this.glowColor,
    required this.startAngle,
    required this.clockwise,
    required this.roundCaps,
    this.dashPattern,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width / 2, size.height / 2) - (strokeWidth / 2);
    final Rect bounds = Rect.fromCircle(center: center, radius: radius);

    // Background circle paint
    final Paint backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Foreground circle paint
    final Paint foregroundPaint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    if (roundCaps) {
      foregroundPaint.strokeCap = StrokeCap.round;
    }

    if (gradient != null) {
      foregroundPaint.shader = gradient!.createShader(bounds);
    } else {
      foregroundPaint.color = color;
    }

    // Add shadow if glow effect is enabled
    if (addGlowEffect) {
      foregroundPaint.maskFilter = MaskFilter.blur(BlurStyle.normal, 3);
    }

    // Draw background circle
    canvas.drawCircle(center, radius, backgroundPaint);

    // Calculate sweep angle
    final double sweepAngle = 2 * math.pi * percentage;
    final double endAngle = clockwise ? sweepAngle : -sweepAngle;

    // Draw progress arc with dash pattern if specified
    if (dashPattern != null && dashPattern!.length >= 2) {
      _drawDashedArc(
          canvas,
          bounds,
          startAngle,
          endAngle,
          foregroundPaint,
          dashPattern![0],
          dashPattern![1]
      );
    } else {
      canvas.drawArc(bounds, startAngle, endAngle, false, foregroundPaint);
    }
  }

  void _drawDashedArc(
      Canvas canvas,
      Rect bounds,
      double startAngle,
      double sweepAngle,
      Paint paint,
      double dashWidth,
      double dashSpace
      ) {
    final double circumference = 2 * math.pi * bounds.width / 2;
    final int dashCount = (circumference / (dashWidth + dashSpace)).floor();
    final double dashAngle = (dashWidth / circumference) * 2 * math.pi;
    final double spaceAngle = (dashSpace / circumference) * 2 * math.pi;

    double currentAngle = startAngle;
    final bool isFullCircle = sweepAngle.abs() >= 2 * math.pi;
    final double targetAngle = isFullCircle
        ? startAngle + 2 * math.pi
        : startAngle + sweepAngle;

    while (
    (sweepAngle >= 0 && currentAngle < targetAngle) ||
        (sweepAngle < 0 && currentAngle > targetAngle)
    ) {
      final double endAngle = currentAngle + (sweepAngle >= 0 ? dashAngle : -dashAngle);

      final double adjustedEndAngle = sweepAngle >= 0
          ? math.min(endAngle, targetAngle)
          : math.max(endAngle, targetAngle);

      canvas.drawArc(
        bounds,
        currentAngle,
        adjustedEndAngle - currentAngle,
        false,
        paint,
      );

      currentAngle = endAngle + (sweepAngle >= 0 ? spaceAngle : -spaceAngle);
    }
  }

  @override
  bool shouldRepaint(_EnhancedCircleProgressPainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.color != color ||
        oldDelegate.gradient != gradient ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.addGlowEffect != addGlowEffect ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.startAngle != startAngle ||
        oldDelegate.clockwise != clockwise ||
        oldDelegate.roundCaps != roundCaps ||
        oldDelegate.dashPattern != dashPattern;
  }
}

/// Usage example showing different configurations
class CircularProgressDemo extends StatefulWidget {
  const CircularProgressDemo({Key? key}) : super(key: key);

  @override
  State<CircularProgressDemo> createState() => _CircularProgressDemoState();
}

class _CircularProgressDemoState extends State<CircularProgressDemo> {
  double _progressValue = 0.65;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enhanced Circular Progress'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20),
            Text('Basic Progress Indicator', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            EnhancedCircularProgress(
              value: _progressValue,
              color: Colors.blue,
              strokeWidth: 12,
            ),

            SizedBox(height: 30),
            Text('With Percentage Display', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            EnhancedCircularProgress(
              value: _progressValue,
              color: Colors.purple,
              strokeWidth: 12,
              showPercentage: true,
            ),

            SizedBox(height: 30),
            Text('With Gradient', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            EnhancedCircularProgress(
              value: _progressValue,
              gradient: SweepGradient(
                colors: [Colors.blue, Colors.purple, Colors.red],
                startAngle: -math.pi / 2,
                endAngle: math.pi * 3 / 2,
              ),
              strokeWidth: 12,
            ),

            SizedBox(height: 30),
            Text('With Glow Effect', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            EnhancedCircularProgress(
              value: _progressValue,
              color: Colors.greenAccent,
              strokeWidth: 14,
              addGlowEffect: true,
              size: 120,
            ),

            SizedBox(height: 30),
            Text('With Dashed Pattern', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            EnhancedCircularProgress(
              value: _progressValue,
              color: Colors.amber,
              strokeWidth: 10,
              dashPattern: [5, 3],
              size: 120,
              backgroundColor: Colors.amber.withOpacity(0.2),
            ),

            SizedBox(height: 30),
            Text('Custom Center Widget', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            EnhancedCircularProgress(
              value: _progressValue,
              color: Colors.red,
              strokeWidth: 8,
              size: 120,
              centerWidget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.battery_charging_full, color: Colors.red),
                  SizedBox(height: 5),
                  Text(
                    '${(_progressValue * 100).toInt()}%',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 30),
            Slider(
              value: _progressValue,
              onChanged: (value) {
                setState(() {
                  _progressValue = value;
                });
              },
              min: 0.0,
              max: 1.0,
            ),
            Text('Change Progress Value'),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}