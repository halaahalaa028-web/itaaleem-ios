import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/entities/course_details.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class GetCourseDetailsUseCase {
  const GetCourseDetailsUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<CourseDetails>> call(int id) =>
      _repository.getCourseDetails(id);
}
