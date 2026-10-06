import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/repositories/exams_repository.dart';

class GetExamQuestionsUseCase {
  const GetExamQuestionsUseCase(this._repository);

  final ExamsRepository _repository;

  Future<Result<List<ExamQuestion>>> call(int examId) =>
      _repository.getExamQuestions(examId);
}
