import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class GetCourseProgressUseCase {
  const GetCourseProgressUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<double>> call(int courseId) =>
      _repository.getCourseProgress(courseId);
}
