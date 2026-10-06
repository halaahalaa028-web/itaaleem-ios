import 'package:itaaleem/core/providers/cache_for.dart';
import 'package:itaaleem/features/subjects/data/datasources/subjects_remote_data_source.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Real-data only — the demo ("دخول تجريبي") path never watches these,
/// rendering [dummySubjects] directly instead (see [SubjectsScreen] and
/// [SubjectDetailScreen]).
final subjectsListProvider = FutureProvider.autoDispose<List<Subject>>((ref) {
  return ref.cached(
    () => ref.read(subjectsRemoteDataSourceProvider).getSubjects(),
  );
});

/// `GET /subjects/{id}` is meant to embed this subject's own `lessons`
/// array directly, but that hasn't held up in practice (mirrors the same
/// "assumed embed doesn't actually come back" issue already found on
/// `GET /centers?code=` and the content list endpoints) — when it comes
/// back empty despite [Subject.lessonsCount] being non-zero, fall back to
/// the dedicated `GET /lessons?subject_id=` call (already used by the home
/// tab) instead of just trusting the empty embed.
final subjectDetailsProvider = FutureProvider.autoDispose.family<Subject, int>((
  ref,
  id,
) async {
  // Cached only 1 min: this carries each lesson's `is_accessible` (lock
  // state), which the center can change from the dashboard at any time.
  return ref.cached(() async {
    final dataSource = ref.read(subjectsRemoteDataSourceProvider);
    final subject = await dataSource.getSubjectDetails(id);
    // An embed shorter than `lessons_count` may be leaving out the paid
    // lessons — fetch the full list in that case too.
    if (subject.lessons.length >= subject.lessonsCount) {
      return subject;
    }
    if (kDebugMode) {
      debugPrint(
        '[subjectDetailsProvider] subject $id: lessonsCount=${subject.lessonsCount} '
        'but embedded lessons=[] — falling back to GET /lessons?subject_id=$id',
      );
    }
    try {
      final lessons = await dataSource.getLessons(subjectId: id);
      if (lessons.length <= subject.lessons.length) return subject;
      return Subject(
        id: subject.id,
        name: subject.name,
        description: subject.description,
        lessonsCount: subject.lessonsCount,
        examsCount: subject.examsCount,
        lessons: lessons,
        exams: subject.exams,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[subjectDetailsProvider] lessons fallback for $id failed: $e',
        );
      }
      return subject;
    }
  }, duration: const Duration(minutes: 1));
});

/// A subject's files (`GET /attachments?subject_id=`), keyed by subject id.
final attachmentsProvider = FutureProvider.autoDispose
    .family<List<SubjectAttachment>, int>((ref, subjectId) {
      return ref.cached(
        () => ref
            .read(subjectsRemoteDataSourceProvider)
            .getAttachments(subjectId),
      );
    });

/// One lesson's files only — key is `(subjectId, lessonId)`.
final lessonAttachmentsProvider = FutureProvider.autoDispose
    .family<List<SubjectAttachment>, (int, int)>((ref, key) {
      return ref.cached(
        () => ref
            .read(subjectsRemoteDataSourceProvider)
            .getAttachments(key.$1, lessonId: key.$2),
      );
    });

/// Home screen's "آخر المحاضرات": the first subject's lessons (capped at
/// 4) — there's no single endpoint for "latest lessons across every
/// subject", so this is the closest real approximation, per the task spec.
final homeLessonsProvider = FutureProvider.autoDispose<List<SubjectLesson>>((
  ref,
) async {
  return ref.cached(() async {
    final subjects = await ref.watch(subjectsListProvider.future);
    if (subjects.isEmpty) return const [];
    return ref
        .read(subjectsRemoteDataSourceProvider)
        .getLessons(subjectId: subjects.first.id, limit: 4);
  });
});

/// Watched by the screens that list subjects: once the list is in, the
/// first subject's details start loading in the background (and stay cached
/// via [subjectDetailsProvider]'s TTL), so opening it is instant.
final prefetchFirstSubjectProvider = Provider.autoDispose<void>((ref) {
  final subjects = ref.watch(subjectsListProvider).valueOrNull;
  if (subjects == null || subjects.isEmpty) return;
  ref.listen(subjectDetailsProvider(subjects.first.id), (_, _) {});
});
