import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/exams/domain/entities/exam_result.dart';
import 'package:itaaleem/features/exams/domain/repositories/exams_repository.dart';

class SubmitExamUseCase {
  const SubmitExamUseCase(this._repository);

  final ExamsRepository _repository;

  Future<Result<ExamResult>> call(
    int examId,
    Map<int, Object> answers, {
    int? attemptId,
    int? timeSpentSeconds,
    Set<int> booleanQuestionIds = const {},
  }) => _repository.submitExam(
    examId,
    answers,
    attemptId: attemptId,
    timeSpentSeconds: timeSpentSeconds,
    booleanQuestionIds: booleanQuestionIds,
  );
}
