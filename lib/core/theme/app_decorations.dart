import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';

/// Reusable box decorations, all derived from the active [ColorScheme] so
/// they follow the center color and dark mode.
class AppDecorations {
  AppDecorations._();

  /// Brand gradient for headers, welcome cards and banners.
  static BoxDecoration gradientHeader(ColorScheme colorScheme) => BoxDecoration(
    gradient: brandGradient(colorScheme),
    borderRadius: BorderRadius.circular(AppRadius.banner),
  );

  /// The gradient alone, for surfaces that set their own shape. Built on
  /// `primary` in both modes (dark mode's primary is a light tone, so text on
  /// it is [onGradient] = `onPrimary`, exactly like a filled button).
  static LinearGradient brandGradient(ColorScheme colorScheme) =>
      LinearGradient(
        begin: AlignmentDirectional.topStart,
        end: AlignmentDirectional.bottomEnd,
        colors: [
          colorScheme.primary,
          colorScheme.primary.withValues(alpha: 0.85),
        ],
      );

  /// Foreground for text/icons on [gradientHeader].
  static Color onGradient(ColorScheme colorScheme) => colorScheme.onPrimary;

  /// Translucent "glass" card over imagery or gradients.
  static BoxDecoration glassCard(ColorScheme colorScheme) => BoxDecoration(
    color: colorScheme.surface.withValues(alpha: 0.8),
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: 0.2),
    ),
  );

  /// Flat card with a hairline border — the default card look.
  static BoxDecoration subtleCard(ColorScheme colorScheme) => BoxDecoration(
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(AppRadius.card),
    border: Border.all(
      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
    ),
  );
}
