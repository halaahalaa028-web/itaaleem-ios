import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_shadows.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Standard surface card: 16px radius, a hairline border, 16px padding.
/// Prefer this over a raw [Card]/[Container] combo for anything that should
/// read as a "card" in the design system.
///
/// Tappable cards ([onTap]) get a ripple plus a subtle press-scale (0.98),
/// so every card in the app responds to touch the same way. [elevated]
/// adds a soft shadow for featured cards that should lift off the page.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderRadius,
    this.borderColor,
    this.gradient,
    this.elevated = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final BorderRadius? borderRadius;

  /// Overrides the hairline border (e.g. a selected/highlighted card).
  final Color? borderColor;

  /// Paints over [color] — for cards with a soft brand-tinted wash.
  final Gradient? gradient;

  final bool elevated;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _pressed = false;

  bool get _interactive => widget.onTap != null || widget.onLongPress != null;

  void _setPressed(bool value) {
    if (_pressed != value && mounted) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadius.card);

    final decoration = BoxDecoration(
      color: widget.color ?? scheme.surface,
      gradient: widget.gradient,
      borderRadius: radius,
      border: Border.all(
        color:
            widget.borderColor ?? scheme.outlineVariant.withValues(alpha: 0.5),
      ),
      boxShadow: widget.elevated ? AppShadows.md(scheme.shadow) : null,
    );

    if (!_interactive) {
      return Container(
        padding: widget.padding,
        decoration: decoration,
        child: widget.child,
      );
    }

    return AnimatedScale(
      scale: _pressed ? 0.98 : 1,
      duration: AppMotion.press,
      curve: Curves.easeOut,
      child: DecoratedBox(
        // Shadow outside the clip so it isn't cut off.
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: decoration.boxShadow,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            onHighlightChanged: _setPressed,
            child: Ink(
              padding: widget.padding,
              decoration: decoration.copyWith(boxShadow: const []),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
