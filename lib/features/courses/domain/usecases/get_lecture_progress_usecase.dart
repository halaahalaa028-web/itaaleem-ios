import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class GetLectureProgressUseCase {
  const GetLectureProgressUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<LectureProgress>> call(int lectureId) =>
      _repository.getLectureProgress(lectureId);
}
