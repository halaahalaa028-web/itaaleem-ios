import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/repositories/exams_repository.dart';

class StartExamUseCase {
  const StartExamUseCase(this._repository);

  final ExamsRepository _repository;

  Future<Result<ExamStart>> call(int examId) => _repository.startExam(examId);
}
