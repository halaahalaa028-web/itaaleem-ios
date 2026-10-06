import 'package:flutter/animation.dart';

/// Spacing scale used across the app instead of hardcoded gaps/padding.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal/vertical padding of a screen's content.
  static const double screenHorizontal = 16;
  static const double screenVertical = 16;

  /// Padding inside a card.
  static const double cardPadding = 16;

  /// Gap between sections on one screen.
  static const double sectionSpacing = 24;

  /// Gap between list items.
  static const double listItemSpacing = 12;

  /// Gap between grid cells.
  static const double gridSpacing = 12;

  /// Gap between small related items (icon + label, chips in a row).
  static const double itemSpacing = 8;

  /// Clearance under the last list item so it isn't hidden by a FAB.
  static const double fabClearance = 96;
}

/// Icon size scale.
class AppIconSize {
  AppIconSize._();

  /// Inline with caption/label text (meta rows, badges).
  static const double xs = 16;

  /// List tiles, buttons, chips.
  static const double sm = 20;

  /// Default: app bar actions, navigation, standalone icons.
  static const double md = 24;

  /// Inside tinted icon tiles on cards.
  static const double lg = 28;

  /// Empty / error state illustrations.
  static const double state = 48;
}

/// Motion tokens — one place for durations and curves so every animation
/// in the app moves with the same rhythm.
class AppMotion {
  AppMotion._();

  /// Press feedback (button/card scale).
  static const Duration press = Duration(milliseconds: 110);

  /// Small state changes (selection, toggles, nav indicator).
  static const Duration short = Duration(milliseconds: 220);

  /// Page transitions and list entrances.
  static const Duration medium = Duration(milliseconds: 300);

  /// Delay between consecutive items of a staggered list.
  static const Duration stagger = Duration(milliseconds: 45);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutBack;
}
