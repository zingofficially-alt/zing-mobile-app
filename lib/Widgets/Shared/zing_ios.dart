import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zing/Service/ThemeProvider.dart';
import 'package:zing/Widgets/Shared/zing_motion.dart';

/// iOS building blocks used across the customer and merchant screens.
///
/// They follow Apple's Human Interface Guidelines: large titles that
/// collapse into a frosted bar, inset grouped lists, tinted icon tiles,
/// action sheets and alerts. The same widgets render on Android so the app
/// looks identical on both platforms.

// ---------------------------------------------------------------------------
// Page scaffold with a collapsing large title
// ---------------------------------------------------------------------------

/// A page with an iOS large title that shrinks into a translucent inline bar
/// as the content scrolls under it.
class ZingLargeTitlePage extends StatelessWidget {
  final String title;
  final List<Widget> slivers;
  final Widget? leading;
  final List<Widget> actions;
  final Future<void> Function()? onRefresh;
  final bool showBack;
  final ScrollController? controller;

  /// Shown under the large title (for example a search field). It scrolls
  /// away with the title.
  final Widget? bottom;

  const ZingLargeTitlePage({
    super.key,
    required this.title,
    required this.slivers,
    this.leading,
    this.actions = const [],
    this.onRefresh,
    this.showBack = false,
    this.controller,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canPop = showBack && Navigator.of(context).canPop();

    return Scaffold(
      body: CustomScrollView(
        controller: controller,
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.82),
            border: null,
            automaticallyImplyLeading: false,
            leading: leading ??
                (canPop
                    ? CupertinoNavigationBarBackButton(
                        color: cs.primary,
                        onPressed: () => Navigator.of(context).maybePop(),
                      )
                    : null),
            trailing: actions.isEmpty
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: actions),
            stretch: true,
          ),
          if (onRefresh != null) CupertinoSliverRefreshControl(onRefresh: onRefresh),
          if (bottom != null) SliverToBoxAdapter(child: bottom),
          ...slivers,
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 96)),
        ],
      ),
    );
  }
}

/// A compact navigation-bar button: tinted icon, no ripple, iOS hit size.
class ZingBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Widget? badge;
  final String? tooltip;

  const ZingBarButton({super.key, required this.icon, this.onPressed, this.badge, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget child = Icon(icon, color: cs.primary, size: 24);
    if (badge != null) {
      child = Stack(clipBehavior: Clip.none, children: [
        child,
        Positioned(right: -6, top: -4, child: badge!),
      ]);
    }
    return Semantics(
      button: true,
      label: tooltip,
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(40, 40),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}

/// Small red count bubble used on bar buttons and tab icons.
class ZingBadge extends StatelessWidget {
  final int count;
  const ZingBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: ZingMotion.fast,
      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
      child: count <= 0
          ? const SizedBox.shrink()
          : Container(
              key: ValueKey(count),
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ZingColors.error,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                style: ZingType.style(11, weight: FontWeight.w600, color: Colors.white, height: 1),
              ),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inset grouped lists (Settings-style)
// ---------------------------------------------------------------------------

/// An inset, rounded group of rows with optional header and footer text.
class ZingGroupedSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;
  final EdgeInsetsGeometry margin;

  /// Where row separators start; 60 lines them up with text after an icon.
  final double separatorIndent;

  const ZingGroupedSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 16),
    this.separatorIndent = 60,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i < children.length - 1) {
        // iOS separators start at the text, not the cell edge.
        rows.add(Padding(
          padding: EdgeInsets.only(left: separatorIndent),
          child: Divider(height: 0.5, thickness: 0.5, color: cs.outline.withValues(alpha: 0.7)),
        ));
      }
    }

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 7),
              child: Text(
                header!.toUpperCase(),
                style: ZingType.footnote(cs.onSurfaceVariant).copyWith(letterSpacing: 0.2),
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(ZingRadius.md),
            child: ColoredBox(
              color: cs.surface,
              child: Column(children: rows),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 7, 16, 0),
              child: Text(footer!, style: ZingType.footnote(cs.onSurfaceVariant)),
            ),
        ],
      ),
    );
  }
}

/// The coloured rounded-square icon used at the start of Settings rows.
class ZingIconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const ZingIconTile({super.key, required this.icon, required this.color, this.size = 30});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.6),
    );
  }
}

/// One row in a [ZingGroupedSection].
class ZingListRow extends StatefulWidget {
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final bool destructive;

  const ZingListRow({
    super.key,
    this.icon,
    this.iconColor,
    this.leading,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.destructive = false,
  });

  @override
  State<ZingListRow> createState() => _ZingListRowState();
}

class _ZingListRowState extends State<ZingListRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tappable = widget.onTap != null;
    final titleColor = widget.destructive ? ZingColors.error : cs.onSurface;

    final leading = widget.leading ??
        (widget.icon != null
            ? ZingIconTile(icon: widget.icon!, color: widget.iconColor ?? cs.primary)
            : null);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: tappable ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: tappable ? () => setState(() => _pressed = false) : null,
      onTapUp: tappable ? (_) => setState(() => _pressed = false) : null,
      onTap: tappable
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        color: _pressed ? cs.onSurface.withValues(alpha: 0.07) : Colors.transparent,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 14)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.title, style: ZingType.body(titleColor)),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: ZingType.footnote(cs.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (widget.value != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(widget.value!, style: ZingType.body(cs.onSurfaceVariant)),
              ),
            if (widget.trailing != null)
              Padding(padding: const EdgeInsets.only(left: 8), child: widget.trailing!),
            if (tappable && widget.showChevron && widget.trailing == null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Icon(CupertinoIcons.chevron_forward,
                    size: 17, color: cs.onSurfaceVariant.withValues(alpha: 0.55)),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Inputs and controls
// ---------------------------------------------------------------------------

/// The iOS rounded search field.
class ZingSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FocusNode? focusNode;
  final bool readOnly;
  final EdgeInsetsGeometry padding;

  const ZingSearchField({
    super.key,
    this.controller,
    this.placeholder = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.focusNode,
    this.readOnly = false,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 10),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final field = CupertinoSearchTextField(
      controller: controller,
      focusNode: focusNode,
      placeholder: placeholder,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onTap: onTap,
      enabled: !readOnly || onTap == null,
      style: ZingType.body(cs.onSurface),
      placeholderStyle: ZingType.body(cs.onSurfaceVariant.withValues(alpha: 0.8)),
      backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.9),
      itemColor: cs.onSurfaceVariant,
      borderRadius: BorderRadius.circular(11),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
    );
    return Padding(
      padding: padding,
      child: readOnly && onTap != null
          ? GestureDetector(onTap: onTap, child: AbsorbPointer(child: field))
          : field,
    );
  }
}

/// The iOS sliding segmented control.
class ZingSegmented<T extends Object> extends StatelessWidget {
  final T value;
  final Map<T, String> segments;
  final ValueChanged<T> onChanged;

  const ZingSegmented({
    super.key,
    required this.value,
    required this.segments,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: value,
        backgroundColor: cs.surfaceContainerHighest,
        thumbColor: dark ? const Color(0xFF636366) : Colors.white,
        padding: const EdgeInsets.all(2),
        onValueChanged: (v) {
          if (v == null) return;
          HapticFeedback.selectionClick();
          onChanged(v);
        },
        children: {
          for (final e in segments.entries)
            e.key: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
              child: Text(
                e.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ZingType.style(13,
                    weight: e.key == value ? FontWeight.w600 : FontWeight.w500,
                    color: cs.onSurface),
              ),
            ),
        },
      ),
    );
  }
}

/// A rounded pill used for categories and filters.
class ZingPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;

  const ZingPill({super.key, required this.label, this.icon, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = selected ? Colors.white : cs.onSurface;
    return ZingPressable(
      onTap: onTap,
      pressedScale: 0.94,
      child: AnimatedContainer(
        duration: ZingMotion.medium,
        curve: ZingMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(100),
          boxShadow: selected
              ? [BoxShadow(color: cs.primary.withValues(alpha: 0.32), blurRadius: 12, offset: const Offset(0, 4))]
              : ZingShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? Colors.white : cs.primary),
              const SizedBox(width: 6),
            ],
            Text(label, style: ZingType.style(14, weight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Primary call-to-action button: full width, filled, with a spring press.
class ZingButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool tinted;
  final bool destructive;

  const ZingButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.tinted = false,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final base = destructive ? ZingColors.error : cs.primary;
    final enabled = onPressed != null && !loading;
    final bg = !enabled
        ? cs.surfaceContainerHighest
        : tinted
            ? base.withValues(alpha: 0.13)
            : base;
    final fg = !enabled ? cs.onSurfaceVariant : (tinted ? base : Colors.white);

    return ZingPressable(
      onTap: enabled ? onPressed : null,
      pressedScale: 0.97,
      child: AnimatedContainer(
        duration: ZingMotion.fast,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ZingRadius.md),
        ),
        child: loading
            ? CupertinoActivityIndicator(color: fg)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[Icon(icon, size: 19, color: fg), const SizedBox(width: 8)],
                  Text(label, style: ZingType.style(17, weight: FontWeight.w600, color: fg)),
                ],
              ),
      ),
    );
  }
}

/// iOS spinner in the app tint, for loading states.
class ZingSpinner extends StatelessWidget {
  final double radius;
  const ZingSpinner({super.key, this.radius = 12});

  @override
  Widget build(BuildContext context) =>
      Center(child: CupertinoActivityIndicator(radius: radius));
}

// ---------------------------------------------------------------------------
// Sheets, alerts and toasts
// ---------------------------------------------------------------------------

class ZingSheetAction {
  final String label;
  final IconData? icon;
  final bool destructive;
  final bool isDefault;
  final VoidCallback onPressed;

  const ZingSheetAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
    this.isDefault = false,
  });
}

/// The iOS action sheet that slides up from the bottom.
Future<void> showZingActionSheet(
  BuildContext context, {
  String? title,
  String? message,
  required List<ZingSheetAction> actions,
  String cancelLabel = 'Cancel',
}) {
  HapticFeedback.lightImpact();
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (sheetContext) => CupertinoActionSheet(
      title: title == null ? null : Text(title),
      message: message == null ? null : Text(message),
      actions: [
        for (final a in actions)
          CupertinoActionSheetAction(
            isDestructiveAction: a.destructive,
            isDefaultAction: a.isDefault,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              a.onPressed();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (a.icon != null) ...[Icon(a.icon, size: 20), const SizedBox(width: 8)],
                Flexible(child: Text(a.label)),
              ],
            ),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () => Navigator.of(sheetContext).pop(),
        child: Text(cancelLabel),
      ),
    ),
  );
}

/// The iOS alert. Returns true when the confirm action was chosen.
Future<bool> showZingAlert(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'OK',
  String? cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: cancelLabel != null,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null
          ? null
          : Padding(padding: const EdgeInsets.only(top: 4), child: Text(message)),
      actions: [
        if (cancelLabel != null)
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
        CupertinoDialogAction(
          isDefaultAction: !destructive,
          isDestructiveAction: destructive,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A rounded sheet with a grabber, for custom content (filters, pickers).
Future<T?> showZingSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: builder,
  );
}

/// A floating, frosted confirmation banner (the iOS "HUD" style).
void showZingToast(BuildContext context, String message, {IconData? icon, bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  if (error) {
    HapticFeedback.heavyImpact();
  } else {
    HapticFeedback.lightImpact();
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      duration: const Duration(milliseconds: 2400),
      content: ZingGlass(
        borderRadius: BorderRadius.circular(ZingRadius.lg),
        color: const Color(0xFF1C1C1E),
        opacity: 0.86,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon ??
                    (error
                        ? CupertinoIcons.exclamationmark_circle_fill
                        : CupertinoIcons.checkmark_circle_fill),
                color: error ? ZingColors.error : ZingColors.success,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message, style: ZingType.subhead(Colors.white))),
            ],
          ),
        ),
      ),
    ));
}

// ---------------------------------------------------------------------------
// Empty and section states
// ---------------------------------------------------------------------------

/// Large section title used inside scrolling pages ("Nearby", "For You").
class ZingSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const ZingSectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(20, 26, 12, 10),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: Text(title, style: ZingType.title2(cs.onSurface))),
          if (actionLabel != null)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              onPressed: onAction,
              child: Text(actionLabel!, style: ZingType.body(cs.primary)),
            ),
        ],
      ),
    );
  }
}
