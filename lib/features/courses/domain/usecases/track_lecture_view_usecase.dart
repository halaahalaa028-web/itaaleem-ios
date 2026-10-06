import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class TrackLectureViewUseCase {
  const TrackLectureViewUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<void>> call(int lectureId) =>
      _repository.trackLectureView(lectureId);
}
