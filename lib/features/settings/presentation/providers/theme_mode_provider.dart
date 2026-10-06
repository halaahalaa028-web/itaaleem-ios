import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'theme_mode';

/// The stored light/dark choice, read once in `main()` *before* `runApp` and
/// injected via a `ProviderScope` override — so the first frame already uses
/// the saved theme instead of flashing the system one and switching a moment
/// later. Defaults to [ThemeMode.system] when nothing was ever chosen.
final initialThemeModeProvider = Provider<ThemeMode>((ref) => ThemeMode.system);

/// Reads the persisted [ThemeMode] (`system` if unset or unreadable).
Future<ThemeMode> loadStoredThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_themeModeKey)) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
    }
  } catch (_) {}
  return ThemeMode.system;
}

/// Persists the student's light/dark choice from the account screen's
/// "الوضع الليلي" toggle across launches (SharedPreferences, restored by
/// [loadStoredThemeMode] on the next start).
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(super.initial);

  Future<void> setDark(bool isDark) async {
    state = isDark ? ThemeMode.dark : ThemeMode.light;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, isDark ? 'dark' : 'light');
    } catch (_) {}
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
      (ref) => ThemeModeController(ref.watch(initialThemeModeProvider)),
    );
