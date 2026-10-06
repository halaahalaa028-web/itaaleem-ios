import 'package:shared_preferences/shared_preferences.dart';

/// Persists the student's preferred video height (e.g. 480) so the next
/// YouTube lecture opens at the same quality — or the closest one it offers.
class PlaybackQualityPrefs {
  static const _key = 'video_playback_quality_height';

  /// `null` until the student has picked a quality themselves.
  static Future<int?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key);
  }

  static Future<void> save(int height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, height);
  }

  static const _youtubeKey = 'yt_quality_height';

  /// The adaptive height the student picked for YouTube lectures and that
  /// worked — `null` means the muxed "الأساسية" stream (the default).
  static Future<int?> loadYoutube() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_youtubeKey);
  }

  static Future<void> saveYoutube(int height) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_youtubeKey, height);
  }

  /// Forgets the saved height (the adaptive stream failed, or the student
  /// went back to the base quality).
  static Future<void> clearYoutube() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_youtubeKey);
  }
}
