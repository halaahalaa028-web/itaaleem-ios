import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/entities/available_course.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class GetAvailableCoursesUseCase {
  const GetAvailableCoursesUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<List<AvailableCourse>>> call() =>
      _repository.getAvailableCourses();
}
