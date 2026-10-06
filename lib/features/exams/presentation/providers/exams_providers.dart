import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/exams/data/datasources/exams_remote_data_source.dart';
import 'package:itaaleem/features/exams/data/repositories/exams_repository_impl.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/usecases/get_exam_details_usecase.dart';
import 'package:itaaleem/features/exams/domain/usecases/get_exam_questions_usecase.dart';
import 'package:itaaleem/features/exams/domain/usecases/get_exam_results_usecase.dart';
import 'package:itaaleem/features/exams/domain/usecases/start_exam_usecase.dart';
import 'package:itaaleem/features/exams/domain/usecases/submit_exam_attempt_usecase.dart';
import 'package:itaaleem/features/exams/domain/entities/exam_result.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/providers/cache_for.dart';
import 'package:itaaleem/features/subjects/presentation/providers/subjects_providers.dart';

final getExamDetailsUseCaseProvider = Provider<GetExamDetailsUseCase>((ref) {
  return GetExamDetailsUseCase(ref.watch(examsRepositoryProvider));
});

final getExamQuestionsUseCaseProvider = Provider<GetExamQuestionsUseCase>((
  ref,
) {
  return GetExamQuestionsUseCase(ref.watch(examsRepositoryProvider));
});

final startExamUseCaseProvider = Provider<StartExamUseCase>((ref) {
  return StartExamUseCase(ref.watch(examsRepositoryProvider));
});

/// An attempt's review (`GET /exam-attempts/{id}/review`), keyed by attempt
/// id.
final examAttemptReviewProvider = FutureProvider.autoDispose
    .family<ExamResult, int>((ref, attemptId) async {
      final result = await ref
          .watch(examsRepositoryProvider)
          .getAttemptReview(attemptId);
      return switch (result) {
        Ok<ExamResult>(:final value) => value,
        Err<ExamResult>(:final failure) => throw failure,
      };
    });

final submitExamUseCaseProvider = Provider<SubmitExamUseCase>((ref) {
  return SubmitExamUseCase(ref.watch(examsRepositoryProvider));
});

final getExamResultsUseCaseProvider = Provider<GetExamResultsUseCase>((ref) {
  return GetExamResultsUseCase(ref.watch(examsRepositoryProvider));
});

/// A single exam's detail (`GET /exams/{id}`), keyed by exam id.
final examDetailsProvider = FutureProvider.family<ExamDetails, int>((
  ref,
  id,
) async {
  final useCase = ref.watch(getExamDetailsUseCaseProvider);
  final result = await useCase(id);
  return switch (result) {
    Ok<ExamDetails>(:final value) => value,
    Err<ExamDetails>(:final failure) => throw failure,
  };
});

/// An exam's questions (`GET /exams/{id}/questions`), keyed by exam id.
final examQuestionsProvider = FutureProvider.family<List<ExamQuestion>, int>((
  ref,
  id,
) async {
  final useCase = ref.watch(getExamQuestionsUseCaseProvider);
  final result = await useCase(id);
  return switch (result) {
    Ok<List<ExamQuestion>>(:final value) => value,
    Err<List<ExamQuestion>>(:final failure) => throw failure,
  };
});

/// This student's past attempts on an exam (`GET /exams/{id}/results`),
/// keyed by exam id.
final examResultsProvider = FutureProvider.autoDispose
    .family<List<ExamAttemptSummary>, int>((ref, id) async {
      if (id <= 0) return const [];
      final useCase = ref.watch(getExamResultsUseCaseProvider);
      final result = await useCase(id);
      return switch (result) {
        Ok<List<ExamAttemptSummary>>(:final value) => value,
        Err<List<ExamAttemptSummary>>(:final failure) => throw failure,
      };
    });

/// The best (highest) past score for an exam, or `null` when there are none
/// yet (or the results call fails) — [ExamsScreen] shows "أفضل درجة: X%"
/// only once this resolves to a value, and silently shows nothing otherwise
/// rather than surfacing an error for what's just a nice-to-have.
final examBestScoreProvider = FutureProvider.autoDispose.family<double?, int>((
  ref,
  examId,
) async {
  try {
    final results = await ref.watch(examResultsProvider(examId).future);
    if (results.isEmpty) return null;
    return results.map((r) => r.percentage).reduce((a, b) => a > b ? a : b);
  } catch (_) {
    return null;
  }
});

/// The "الامتحانات" tab's list (`GET /exams`) — real accounts only, the
/// demo ("دخول تجريبي") path renders its own dummy list instead.
final examsListProvider = FutureProvider.autoDispose<List<ExamSummary>>((
  ref,
) async {
  // The unscoped `GET /exams` doesn't return everything, so every subject's
  // exams (`?subject_id=`) are merged in. Without subjects (still loading
  // or failed) the unscoped list alone is used.
  Map<int, String> subjects = const {};
  try {
    final list = await ref.watch(subjectsListProvider.future);
    subjects = {for (final s in list) s.id: s.name};
  } catch (_) {}
  final result = await ref.cached(
    () => ref.read(examsRepositoryProvider).getExams(subjects: subjects),
  );
  return switch (result) {
    Ok<List<ExamSummary>>(:final value) => value,
    Err<List<ExamSummary>>(:final failure) => throw failure,
  };
});

/// A lecture's own exams (`GET /lectures/{id}/exams`) — never its
/// subject's. Exams without a real id (≤ 0) are dropped by the data source.
final lectureExamsProvider = FutureProvider.autoDispose
    .family<List<ExamSummary>, int>((ref, lectureId) async {
      if (lectureId <= 0) return const [];
      final own = await ref
          .read(examsRemoteDataSourceProvider)
          .getLectureExams(lectureId);
      return List<ExamSummary>.from(own ?? const []);
    });

/// Whether a lecture has any exam — the "فيها امتحان" mark on its tile.
/// Quietly `false` when the call fails.
final lectureHasExamsProvider = FutureProvider.autoDispose.family<bool, int>((
  ref,
  lectureId,
) async {
  try {
    return (await ref.watch(lectureExamsProvider(lectureId).future))
        .isNotEmpty;
  } catch (_) {
    return false;
  }
});

/// One subject's exams (`GET /exams?subject_id=`), keyed by subject id.
final subjectExamsProvider = FutureProvider.autoDispose
    .family<List<ExamSummary>, int>((ref, subjectId) async {
      final result = await ref.cached(
        () => ref.read(examsRepositoryProvider).getSubjectExams(subjectId),
      );
      return switch (result) {
        Ok<List<ExamSummary>>(:final value) => value,
        Err<List<ExamSummary>>(:final failure) => throw failure,
      };
    });
