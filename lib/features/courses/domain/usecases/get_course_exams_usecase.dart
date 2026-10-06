import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/entities/course_details.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class GetCourseExamsUseCase {
  const GetCourseExamsUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<List<CourseExam>>> call(int courseId) =>
      _repository.getCourseExams(courseId);
}
