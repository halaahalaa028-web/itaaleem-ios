import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_colors.dart';
import 'package:itaaleem/core/theme/app_theme.dart';

/// Fallback brand color when the center has none (or an unparsable one).
const Color defaultPrimaryColor = AppColors.defaultPrimary;

/// Parses `#RRGGBB` (or `RRGGBB`); `null` when missing/invalid.
Color? tryParseHexColor(String? hex) {
  if (hex == null) return null;
  final normalized = hex.trim().replaceFirst('#', '');
  if (normalized.length != 6) return null;
  final value = int.tryParse('FF$normalized', radix: 16);
  return value == null ? null : Color(value);
}

/// The app's light/dark [ThemeData] for a center's brand color — the default
/// brand gets the hand-tuned schemes, any other color a scheme generated
/// from it (see [AppColors.fromCenterColor]).
class DynamicTheme {
  DynamicTheme._();

  // Built once per brand color: building a ThemeData (fromSeed + every
  // component theme + the Cairo text theme) is expensive, and `App` rebuilds
  // on every light/dark toggle — recomputing both made the switch stutter.
  static final _light = <int, ThemeData>{};
  static final _dark = <int, ThemeData>{};

  static ThemeData light(Color primary) => _light.putIfAbsent(
    primary.toARGB32(),
    () => AppTheme.light(centerColor: primary),
  );

  static ThemeData dark(Color primary) => _dark.putIfAbsent(
    primary.toARGB32(),
    () => AppTheme.dark(centerColor: primary),
  );
}
