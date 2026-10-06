import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';

/// Nothing-here-yet state: an icon inside a soft brand-tinted halo, a title,
/// an optional subtitle and an optional action (as opposed to
/// [AppErrorState], which is for a failed load).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon = Icons.inbox_rounded,
    this.action,
    this.padding = const EdgeInsets.all(AppSpacing.xxl),
  });

  final String title;
  final String? subtitle;
  final EdgeInsetsGeometry padding;

  /// `null` hides the icon (inline section placeholders).
  final IconData? icon;

  /// Optional button under the text (e.g. "تصفح المواد").
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Icon-less = an inline section note: quiet body text, no halo.
    if (icon == null) {
      return Center(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: text.bodySmall,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpacing.base),
                action!,
              ],
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: padding,
        child: FadeSlideIn(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StateIllustration(
                  icon: icon!,
                  color: scheme.primary,
                  background: scheme.primaryContainer,
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The large icon of an empty/error state: the glyph on a filled circle,
/// inside a fainter outer ring — a lightweight stand-in for an illustration
/// that tints itself from the theme (brand for empty, error for failures).
class StateIllustration extends StatelessWidget {
  const StateIllustration({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background.withValues(alpha: 0.35),
      ),
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background.withValues(alpha: 0.8),
        ),
        child: Icon(icon, size: AppIconSize.state, color: color),
      ),
    );
  }
}
