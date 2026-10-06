/// Corner-radius scale used across the app instead of hardcoded values.
class AppRadius {
  AppRadius._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double full = 999;

  // Named aliases
  /// Buttons sit between inputs (12) and cards (16), so a button inside a
  /// card still reads as nested.
  static const double button = 14;
  static const double card = lg;
  static const double input = md;
  static const double dialog = xl;
  static const double bottomSheet = xxl;
  static const double chip = xl;
  static const double avatar = full;
  static const double image = md;
  static const double banner = lg;

  /// Pill shape for the category chips — same as [xxl].
  static const double pill = xxl;
}
