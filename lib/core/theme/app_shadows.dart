import 'package:flutter/material.dart';

/// Soft, layered shadows. Pass `Theme.of(context).colorScheme.shadow`.
/// Cards are flat by default (see `AppTheme`); these are for the few
/// surfaces that must lift off the page (featured cards, floating bars).
class AppShadows {
  AppShadows._();

  static List<BoxShadow> sm(Color shadowColor) => [
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> md(Color shadowColor) => [
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> lg(Color shadowColor) => [
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: shadowColor.withValues(alpha: 0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}
