import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';

/// Common interface for progress reporters — both online
/// ([PlaybackProgressReporter]) and offline ([OfflineProgressReporter]).
///
/// [AdvancedDirectPlayer] and [LecturePlayerChooser] accept a
/// `ProgressReporter?` so either variant can be plugged in transparently.
abstract class ProgressReporter {
  /// Called from the player's position stream on every tick.
  void onPositionChanged(Duration position, Duration duration);

  /// Immediately sends/saves the latest position (called on pause, exit).
  Future<void> flush();

  /// Reports 100 % completion.
  Future<void> reportCompleted(Duration duration);

  /// Flushes any pending progress and tears down internal timers.
  Future<void> dispose();
}

/// Throttled online progress reporter for lecture/lesson video playback.
///
/// Reports `{watched_seconds, total_seconds, percentage}` (plus the legacy
/// `position`/`duration`/`progress_percentage`) to
/// `POST /lessons/{id}/progress` at most once every [_interval] seconds,
/// plus immediately on pause, exit, video completion, and dispose — exactly
/// what the spec calls for ("كل 15 ثانية + Pause + Exit + Dispose +
/// Completion").
///
/// All network errors are silently caught — progress is best-effort and must
/// never interrupt playback.
class PlaybackProgressReporter implements ProgressReporter {
  PlaybackProgressReporter({required Dio dio, required this.lessonId})
    : _dio = dio;

  final Dio _dio;
  final int lessonId;

  static const _interval = Duration(seconds: 15);

  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  DateTime? _lastReportedAt;
  bool _disposed = false;

  Timer? _throttleTimer;

  @override
  void onPositionChanged(Duration position, Duration duration) {
    if (_disposed) return;
    _lastPosition = position;
    _lastDuration = duration;

    _throttleTimer ??= Timer.periodic(_interval, (_) => _send());
  }

  @override
  Future<void> flush() async {
    if (_disposed) return;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    await _send();
  }

  @override
  Future<void> reportCompleted(Duration duration) async {
    if (_disposed) return;
    _lastPosition = duration;
    _lastDuration = duration;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    await _send(forcePercentage: 100);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    await _send();
  }

  Future<void> _send({int? forcePercentage}) async {
    final pos = _lastPosition.inSeconds;
    final dur = _lastDuration.inSeconds;
    if (dur <= 0) return;

    final now = DateTime.now();
    if (_lastReportedAt != null &&
        forcePercentage == null &&
        now.difference(_lastReportedAt!) < const Duration(seconds: 2)) {
      return;
    }

    final percentage =
        forcePercentage ?? ((pos / dur) * 100).round().clamp(0, 100);

    try {
      await _dio.post<dynamic>(
        ApiEndpoints.lectureProgress(lessonId),
        data: {
          'watched_seconds': pos,
          'total_seconds': dur,
          'percentage': percentage,
          // Legacy names, kept so an older server still records progress.
          'position': pos,
          'duration': dur,
          'progress_percentage': percentage,
        },
      );
      _lastReportedAt = now;
      if (kDebugMode) {
        debugPrint(
          '[ProgressReporter] lesson=$lessonId pos=${pos}s '
          'dur=${dur}s pct=$percentage%',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProgressReporter] POST failed (best-effort): $e');
      }
    }
  }
}
