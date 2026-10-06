import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class PostLectureProgressUseCase {
  const PostLectureProgressUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<void>> call(
    int lectureId, {
    required int positionSeconds,
    required int durationSeconds,
    required double progressPercentage,
  }) => _repository.postLectureProgress(
    lectureId,
    positionSeconds: positionSeconds,
    durationSeconds: durationSeconds,
    progressPercentage: progressPercentage,
  );
}
