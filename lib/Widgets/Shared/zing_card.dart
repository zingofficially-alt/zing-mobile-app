import 'package:flutter/material.dart';
import 'package:zing/Service/ThemeProvider.dart';

class ZingCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final double? borderRadius;

  const ZingCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.boxShadow,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? 20;

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: ZingSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: boxShadow ?? ZingShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(ZingSpacing.md),
            child: child,
          ),
        ),
      ),
    );
  }
}
