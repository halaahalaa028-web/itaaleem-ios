import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/repositories/exams_repository.dart';

class GetExamResultsUseCase {
  const GetExamResultsUseCase(this._repository);

  final ExamsRepository _repository;

  Future<Result<List<ExamAttemptSummary>>> call(int examId) =>
      _repository.getExamResults(examId);
}
