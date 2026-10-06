import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/auth/domain/entities/student.dart';
import 'package:itaaleem/features/video/data/offline/offline_database.dart';

/// Keeps downloaded offline videos honest against the student's real
/// enrollment, and flushes progress recorded while playing offline back to
/// the server.
///
/// [runOnceForSession] is meant to be called once, right after the app
/// restores its session (`GET /profile`, already fresh by then — see
/// [AuthController.build]) — no center joined means every completed/in-
/// progress download gets marked `expired`; a row whose own `expiresAt` has
/// separately passed is expired too. Never called for a demo session, which
/// has nothing to check against.
class OfflineLicenseChecker {
  OfflineLicenseChecker({required Dio apiDio, required OfflineDatabase db})
    : _apiDio = apiDio,
      _db = db;

  final Dio _apiDio;
  final OfflineDatabase _db;

  bool _hasRunThisSession = false;

  Future<void> runOnceForSession(Student student) async {
    if (_hasRunThisSession || student.isDemo) return;
    _hasRunThisSession = true;
    await run(student);
  }

  Future<void> run(Student student) async {
    if (student.centerId == null) {
      await _db.markAllExpired();
    } else {
      await _expireByDeadline();
    }
    await syncPendingProgress();
  }

  Future<void> _expireByDeadline() async {
    final now = DateTime.now();
    final rows = await _db.getAll();
    for (final row in rows) {
      if (row.downloadStatus == 'completed' &&
          row.expiresAt != null &&
          row.expiresAt!.isBefore(now)) {
        await _db.updateByLessonId(
          row.lessonId,
          (base) => base.copyWith(downloadStatus: const Value('expired')),
        );
      }
    }
  }

  /// Flushes `OfflineVideos.pendingSync*` (progress recorded while playing
  /// offline, with no internet to report it to right away) to
  /// `POST /lectures/{id}/progress`, clearing each row's pending fields only
  /// once its own post succeeds.
  Future<void> syncPendingProgress() async {
    final rows = await _db.getPendingSync();
    for (final row in rows) {
      try {
        await _apiDio.post<dynamic>(
          ApiEndpoints.lectureProgress(row.lessonId),
          data: {
            'position': row.pendingSyncPositionSeconds,
            'duration': row.pendingSyncDurationSeconds,
            'progress_percentage': row.pendingSyncProgressPercentage,
          },
        );
        await _db.clearPendingSync(row.lessonId);
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint(
            '[OfflineLicenseChecker] progress sync failed for lesson '
            '${row.lessonId}: $e\n$stackTrace',
          );
        }
      }
    }
  }
}

final offlineLicenseCheckerProvider = Provider<OfflineLicenseChecker>((ref) {
  return OfflineLicenseChecker(
    apiDio: ref.watch(dioClientProvider),
    db: ref.watch(offlineDatabaseProvider),
  );
});
