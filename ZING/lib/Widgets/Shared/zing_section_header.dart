import 'package:flutter/material.dart';
import 'package:zing/Service/ThemeProvider.dart';

class ZingSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final String? actionText;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry? padding;

  const ZingSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.actionText,
    this.onAction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;

    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(ZingSpacing.lg, ZingSpacing.xl, ZingSpacing.lg, ZingSpacing.md),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(ZingSpacing.sm),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.headlineSmall,
            ),
          ),
          if (actionText != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionText!,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
