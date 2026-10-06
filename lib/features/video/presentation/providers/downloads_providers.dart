import 'package:itaaleem/features/video/data/offline/offline_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every non-cancelled download, newest first — backs the "المحمّلات"
/// screen's list. A `StreamProvider` (not `FutureProvider`) so a download's
/// progress/status updates (written by `OfflineDownloadManager` straight
/// into the same `OfflineDatabase` row) show up live with no manual
/// invalidation.
final downloadedVideosProvider = StreamProvider.autoDispose<List<OfflineVideo>>((
  ref,
) {
  return ref.watch(offlineDatabaseProvider).watchAll();
});

/// One lesson's download row, if any — drives the download button on
/// [LecturePlayerScreen] (queued/downloading/paused/completed/failed/
/// expired all render differently there).
final offlineVideoByLessonProvider = StreamProvider.autoDispose
    .family<OfflineVideo?, int>((ref, lessonId) {
      return ref.watch(offlineDatabaseProvider).watchByLessonId(lessonId);
    });
