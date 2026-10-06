import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/repositories/exams_repository.dart';

class GetExamDetailsUseCase {
  const GetExamDetailsUseCase(this._repository);

  final ExamsRepository _repository;

  Future<Result<ExamDetails>> call(int examId) =>
      _repository.getExamDetails(examId);
}
