import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/entities/course.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class GetCoursesUseCase {
  const GetCoursesUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<List<Course>>> call() => _repository.getCourses();
}
