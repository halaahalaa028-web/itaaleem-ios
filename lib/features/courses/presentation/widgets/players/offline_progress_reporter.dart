import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:itaaleem/features/courses/presentation/widgets/players/playback_progress_reporter.dart';
import 'package:itaaleem/features/video/data/offline/offline_database.dart';

/// Local-only progress reporter for offline playback — mirrors the throttled
/// cadence of [PlaybackProgressReporter] but writes to `OfflineDatabase`
/// (`pendingSync*` columns) instead of calling `POST /lessons/{id}/progress`.
///
/// Pending rows are flushed to the server by
/// [OfflineLicenseChecker.syncPendingProgress] once connectivity returns
/// (called at app startup via `runOnceForSession`).
///
/// Usage is identical to [PlaybackProgressReporter]:
/// ```dart
/// final reporter = OfflineProgressReporter(db: db, lessonId: 42);
/// // position stream:
/// reporter.onPositionChanged(position, duration);
/// // pause:
/// reporter.flush();
/// // completed:
/// reporter.reportCompleted(duration);
/// // dispose:
/// reporter.dispose();
/// ```
class OfflineProgressReporter implements ProgressReporter {
  OfflineProgressReporter({required OfflineDatabase db, required this.lessonId})
    : _db = db;

  final OfflineDatabase _db;
  final int lessonId;

  static const _interval = Duration(seconds: 15);

  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;
  bool _disposed = false;

  Timer? _throttleTimer;

  /// Called from the player's position stream on every tick. Throttles to
  /// one DB write per [_interval].
  @override
  void onPositionChanged(Duration position, Duration duration) {
    if (_disposed) return;
    _lastPosition = position;
    _lastDuration = duration;

    _throttleTimer ??= Timer.periodic(_interval, (_) => _save());
  }

  /// Immediately saves the latest position (called on pause, exit, etc.).
  @override
  Future<void> flush() async {
    if (_disposed) return;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    await _save();
  }

  /// Saves 100 % completion — call when the player's `completed` stream fires.
  @override
  Future<void> reportCompleted(Duration duration) async {
    if (_disposed) return;
    _lastPosition = duration;
    _lastDuration = duration;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    await _save(forcePercentage: 100);
  }

  /// Flushes any pending progress and tears down the timer.
  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _throttleTimer?.cancel();
    _throttleTimer = null;
    await _save();
  }

  Future<void> _save({int? forcePercentage}) async {
    final pos = _lastPosition.inSeconds;
    final dur = _lastDuration.inSeconds;
    if (dur <= 0) return;

    final percentage =
        forcePercentage ?? ((pos / dur) * 100).round().clamp(0, 100);

    try {
      await _db.updateByLessonId(
        lessonId,
        (base) => base.copyWith(
          pendingSyncPositionSeconds: Value(pos),
          pendingSyncDurationSeconds: Value(dur),
          pendingSyncProgressPercentage: Value(percentage.toDouble()),
        ),
      );
      if (kDebugMode) {
        debugPrint(
          '[OfflineProgressReporter] lesson=$lessonId pos=${pos}s '
          'dur=${dur}s pct=$percentage% (saved locally)',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineProgressReporter] DB write failed: $e');
      }
    }
  }
}
