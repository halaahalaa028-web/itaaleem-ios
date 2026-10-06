import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_colors.dart';
import 'package:itaaleem/core/theme/app_decorations.dart';

/// Theme-aware color names for screens. Everything comes from the active
/// [ColorScheme] (default brand, a center's generated scheme, light or dark),
/// plus the brand-fixed semantic colors in their light/dark variants.
/// Read through `context.palette`.
class AppPalette {
  const AppPalette._(this._theme);

  final ThemeData _theme;

  ColorScheme get _scheme => _theme.colorScheme;
  bool get isDark => _theme.brightness == Brightness.dark;

  // ─── Surfaces ───
  Color get background => _theme.scaffoldBackgroundColor;
  Color get surface => _scheme.surface;
  Color get surfaceVariant => _scheme.surfaceContainerHighest;
  Color get border => _scheme.outlineVariant;
  Color get borderLight => _scheme.outlineVariant.withValues(alpha: 0.5);
  Color get divider => _scheme.outlineVariant.withValues(alpha: 0.3);

  // ─── Brand ───
  /// Brand color as a foreground/fill — follows the center color and dark
  /// mode (a lighter tone there).
  Color get primary => _scheme.primary;
  Color get onPrimary => _scheme.onPrimary;
  Color get gold => _scheme.tertiary;
  Color get onGold => _scheme.onTertiary;

  /// Brand gradient for headers/banners; text on it is [onPrimary].
  LinearGradient get brandGradient => AppDecorations.brandGradient(_scheme);

  /// The brand color as a foreground on an always-dark surface (video
  /// player, PDF viewer chrome) — a light tone of the center's color in
  /// both theme modes, where [primary] would be a dark tone in light mode.
  Color get primaryOnDark => isDark ? _scheme.primary : _scheme.inversePrimary;

  // ─── Text ───
  Color get textPrimary => _scheme.onSurface;
  Color get textSecondary => _scheme.onSurfaceVariant;
  Color get textTertiary => _scheme.outline;

  /// Disabled text/icons (M3: onSurface at 38%).
  Color get textDisabled => _scheme.onSurface.withValues(alpha: 0.38);

  // ─── Loading skeletons ───
  Color get shimmerBase => _scheme.surfaceContainerHigh;
  Color get shimmerHighlight => _scheme.surfaceContainerLow;

  // ─── Tinted fills (chips, icon backgrounds, highlighted rows) ───
  Color get primarySurface => _scheme.primaryContainer;
  Color get primaryMuted => _scheme.surfaceContainer;
  Color get primaryBorder => _scheme.outlineVariant;
  Color get accentSurface => _scheme.tertiaryContainer;

  // ─── Semantic ───
  Color get success => isDark ? AppColors.successDark : AppColors.success;
  Color get warning => isDark ? AppColors.warningDark : AppColors.warning;
  Color get error => _scheme.error;
  Color get info => isDark ? AppColors.infoDark : AppColors.info;

  Color get successLight => isDark
      ? AppColors.successDark.withValues(alpha: 0.16)
      : AppColors.successLight;
  Color get warningLight => isDark
      ? AppColors.warningDark.withValues(alpha: 0.16)
      : AppColors.warningLight;
  Color get errorLight => _scheme.errorContainer;
  Color get infoLight =>
      isDark ? AppColors.infoDark.withValues(alpha: 0.16) : AppColors.infoLight;

  LinearGradient get cardGradient => LinearGradient(
    begin: AlignmentDirectional.topStart,
    end: AlignmentDirectional.bottomEnd,
    colors: [primarySurface, accentSurface],
  );
}

extension AppPaletteContext on BuildContext {
  AppPalette get palette => AppPalette._(Theme.of(this));
}
