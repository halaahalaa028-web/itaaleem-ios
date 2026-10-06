import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/connectivity_provider.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/video/data/offline/offline_database.dart';

/// Uploads progress recorded while playing offline (`OfflineVideos.pendingSync*`)
/// as soon as connectivity returns during a session, instead of only at app
/// launch. Progress is best-effort: every failure is swallowed and the row
/// stays pending for the next attempt.
class OfflineProgressSyncService {
  OfflineProgressSyncService({required OfflineDatabase db, required Dio dio})
    : _db = db,
      _dio = dio;

  final OfflineDatabase _db;
  final Dio _dio;

  bool _isSyncing = false;

  Future<void> syncPendingProgress() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final rows = await _db.getPendingSync();
      for (final row in rows) {
        try {
          await _dio.post<dynamic>(
            ApiEndpoints.lectureProgress(row.lessonId),
            data: {
              'position': row.pendingSyncPositionSeconds,
              'duration': row.pendingSyncDurationSeconds,
              'progress_percentage': row.pendingSyncProgressPercentage,
            },
          );
          await _db.clearPendingSync(row.lessonId);
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              '[OfflineProgressSyncService] sync failed for lesson '
              '${row.lessonId}: $e',
            );
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[OfflineProgressSyncService] could not read pending: $e');
      }
    } finally {
      _isSyncing = false;
    }
  }
}

/// Watches connectivity for the lifetime of the app (activated from `App`) and
/// flushes pending offline progress whenever the device comes back online with
/// a real (non-demo) signed-in student.
final offlineProgressSyncServiceProvider = Provider<OfflineProgressSyncService>(
  (ref) {
    final service = OfflineProgressSyncService(
      db: ref.read(offlineDatabaseProvider),
      dio: ref.read(dioClientProvider),
    );

    void syncIfEligible() {
      final student = ref.read(authControllerProvider).valueOrNull;
      if (student == null || student.isDemo) return;
      service.syncPendingProgress();
    }

    ref.listen<AsyncValue<bool>>(connectivityStatusProvider, (previous, next) {
      if (next.valueOrNull == true && previous?.valueOrNull != true) {
        syncIfEligible();
      }
    });

    return service;
  },
);
