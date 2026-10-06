import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

enum AppButtonVariant { primary, secondary, text }

/// Unified button widget: 52px tall, 14px corners and a bold 16px label
/// (all from the theme's button themes), with a press-scale (0.95) on top
/// of the ripple. Use the named constructors
/// ([AppButton.primary], [AppButton.secondary], [AppButton.text]) rather
/// than the default constructor.
class AppButton extends StatefulWidget {
  const AppButton.primary(
    this.text, {
    super.key,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
  }) : variant = AppButtonVariant.primary,
       color = null;

  const AppButton.secondary(
    this.text, {
    super.key,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
    this.color,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text(
    this.text, {
    super.key,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.loading = false,
    this.color,
  }) : variant = AppButtonVariant.text;

  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool expand;
  final bool loading;

  /// Overrides the variant's default [context.palette.primary] accent — e.g. a
  /// destructive "تسجيل الخروج" secondary button in [context.palette.error].
  /// Has no effect on [AppButton.primary], whose background is always the
  /// brand primary color.
  final Color? color;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.press,
    lowerBound: 0.95,
    upperBound: 1.0,
    value: 1.0,
  );

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (!_enabled) return;
    _controller.reverse();
  }

  void _onTapUp(TapUpDetails details) => _controller.forward();

  void _onTapCancel() => _controller.forward();

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _controller,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        // The themes' `minimumSize: Size.fromHeight(52)` means an infinite
        // minimum width, which throws "BoxConstraints forces an infinite
        // width" wherever the parent doesn't bound the width (a Row, a
        // sliver's cross axis in some layouts). Expand only when bounded,
        // and give the button a finite minimum otherwise.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bounded = constraints.hasBoundedWidth;
            return SizedBox(
              width: widget.expand && bounded ? double.infinity : null,
              height: 52,
              child: _buildContent(context, fillWidth: widget.expand && bounded),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, {required bool fillWidth}) {
    final minimumSize = Size(fillWidth ? double.infinity : 64, 52);
    final accent = widget.color ?? context.palette.primary;
    final label = widget.loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: widget.variant == AppButtonVariant.primary
                  ? context.palette.onPrimary
                  : accent,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: AppIconSize.sm),
                const SizedBox(width: AppSpacing.sm),
              ],
              Text(widget.text),
            ],
          );

    switch (widget.variant) {
      case AppButtonVariant.primary:
        return ElevatedButton(
          onPressed: _enabled ? widget.onPressed : null,
          // A loading button keeps its brand color instead of greying out.
          style: ElevatedButton.styleFrom(
            minimumSize: minimumSize,
            disabledBackgroundColor: widget.loading
                ? context.palette.primary.withValues(alpha: 0.7)
                : null,
          ),
          child: label,
        );
      case AppButtonVariant.secondary:
        return OutlinedButton(
          onPressed: _enabled ? widget.onPressed : null,
          style: widget.color == null
              ? OutlinedButton.styleFrom(minimumSize: minimumSize)
              : OutlinedButton.styleFrom(
                  minimumSize: minimumSize,
                  foregroundColor: accent,
                  side: BorderSide(color: accent, width: 1.5),
                ),
          child: label,
        );
      case AppButtonVariant.text:
        return TextButton(
          onPressed: _enabled ? widget.onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: Size(64, fillWidth ? 52 : 40),
            foregroundColor: widget.color == null ? null : accent,
          ),
          child: label,
        );
    }
  }
}
