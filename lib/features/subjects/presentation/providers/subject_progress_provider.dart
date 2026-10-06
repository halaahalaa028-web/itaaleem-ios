import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/providers/cache_for.dart';
import 'package:itaaleem/features/courses/data/datasources/courses_remote_data_source.dart';
import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';
import 'package:itaaleem/features/subjects/presentation/providers/subjects_providers.dart';

/// Each lesson's saved playback progress (`GET /lessons/{id}/progress`, the
/// same call the player makes for "متابعة من…؟"), keyed by lesson id —
/// there's no per-subject progress endpoint, so this fans out per lesson.
///
/// Only lessons whose video URL was actually sent are asked about (a
/// withheld URL means the student can't have watched it), a few at a time.
/// Best-effort: a lesson whose call fails is simply left out.
final subjectLessonsProgressProvider = FutureProvider.autoDispose
    .family<Map<int, LectureProgress>, int>((ref, subjectId) async {
      final subject = await ref.watch(subjectDetailsProvider(subjectId).future);
      return ref.cached(() async {
        final source = ref.read(coursesRemoteDataSourceProvider);
        final ids = [
          for (final l in subject.lessons)
            if (l.canPlayVideo) l.id,
        ];
        final result = <int, LectureProgress>{};
        const batch = 6;
        for (var i = 0; i < ids.length; i += batch) {
          final chunk = ids.skip(i).take(batch);
          final entries = await Future.wait(
            chunk.map((id) async {
              try {
                return MapEntry(id, await source.getLectureProgress(id));
              } catch (e) {
                if (kDebugMode) {
                  debugPrint('[subjectLessonsProgress] lesson $id: $e');
                }
                return null;
              }
            }),
          );
          for (final e in entries) {
            if (e != null) result[e.key] = e.value;
          }
        }
        return result;
      }, duration: const Duration(minutes: 1));
    });

/// 0.0–1.0 watched fraction of one lesson; position/duration wins when both
/// are known, since `progress_percentage` is reported on a 0–100 scale.
double lessonWatchedFraction(LectureProgress p) {
  if (p.isCompleted) return 1;
  if (p.durationSeconds > 0 && p.positionSeconds > 0) {
    return (p.positionSeconds / p.durationSeconds).clamp(0.0, 1.0);
  }
  return (p.progressPercentage / 100).clamp(0.0, 1.0);
}

/// What the subject screen needs out of [subjectLessonsProgressProvider]:
/// which lessons are done / in progress, the "آخر مشاهدة" one, and where
/// "متابعة التعلم" should land.
class SubjectProgressSummary {
  const SubjectProgressSummary._({
    required this.total,
    required this.completedIds,
    required this.inProgress,
    required this.lastWatchedId,
    required this.continueLesson,
  });

  /// [lessons] must already be in display order.
  factory SubjectProgressSummary.from(
    List<SubjectLesson> lessons,
    Map<int, LectureProgress> progress,
  ) {
    final completed = <int>{};
    final inProgress = <int, double>{};
    for (final lesson in lessons) {
      final p = progress[lesson.id];
      if (p == null) continue;
      final fraction = lessonWatchedFraction(p);
      if (fraction >= 0.9) {
        completed.add(lesson.id);
      } else if (fraction > 0 || p.positionSeconds > 5) {
        inProgress[lesson.id] = fraction;
      }
    }

    // The API keeps no "watched at" timestamp, so the furthest lesson the
    // student has touched stands in for the most recently watched one:
    // the last one in progress, else the last one completed.
    int? lastWatched;
    for (final lesson in lessons.reversed) {
      if (inProgress.containsKey(lesson.id)) {
        lastWatched = lesson.id;
        break;
      }
    }
    if (lastWatched == null) {
      for (final lesson in lessons.reversed) {
        if (completed.contains(lesson.id)) {
          lastWatched = lesson.id;
          break;
        }
      }
    }

    // Resume the lesson in progress; otherwise move on to the first lesson
    // after the last finished one (or start from the very first).
    SubjectLesson? target;
    if (lastWatched != null && inProgress.containsKey(lastWatched)) {
      target = lessons.firstWhere((l) => l.id == lastWatched);
    } else if (lessons.isNotEmpty) {
      final lastIndex = lastWatched == null
          ? -1
          : lessons.indexWhere((l) => l.id == lastWatched);
      target = lessons
          .skip(lastIndex + 1)
          .firstWhere(
            (l) => !completed.contains(l.id),
            orElse: () => lessons[lastIndex < 0 ? 0 : lastIndex],
          );
    }

    return SubjectProgressSummary._(
      total: lessons.length,
      completedIds: completed,
      inProgress: inProgress,
      lastWatchedId: lastWatched,
      continueLesson: target,
    );
  }

  final int total;
  final Set<int> completedIds;

  /// Lesson id → watched fraction, for lessons started but not finished.
  final Map<int, double> inProgress;
  final int? lastWatchedId;
  final SubjectLesson? continueLesson;

  int get completedCount => completedIds.length;
  double get fraction => total == 0 ? 0 : completedCount / total;
  bool get hasStarted => completedIds.isNotEmpty || inProgress.isNotEmpty;
}
