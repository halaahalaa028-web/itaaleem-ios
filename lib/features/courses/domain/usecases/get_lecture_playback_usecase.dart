import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class GetLecturePlaybackUseCase {
  const GetLecturePlaybackUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<LecturePlaybackInfo>> call(int lectureId) =>
      _repository.getLecturePlayback(lectureId);
}
