import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class RequestEnrollmentUseCase {
  const RequestEnrollmentUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<String>> call(int courseId) =>
      _repository.requestEnrollment(courseId);
}
