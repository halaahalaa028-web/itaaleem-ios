import 'package:shared_preferences/shared_preferences.dart';

/// Persists the student's preferred playback speed across lectures — shared
/// by every media_kit-backed player (private-server and YouTube alike), so
/// picking e.g. 1.5x once sticks for the next video too instead of resetting
/// to 1x every time.
class PlaybackSpeedPrefs {
  static const _key = 'video_playback_speed';

  static Future<double> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_key) ?? 1.0;
  }

  static Future<void> save(double speed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, speed);
  }
}
