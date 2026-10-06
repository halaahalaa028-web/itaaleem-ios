import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class PostVideoProgressUseCase {
  const PostVideoProgressUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<VideoProgress>> call(
    int videoId, {
    required int lastPositionSeconds,
    required double watchPercentage,
    required int totalWatchTimeSeconds,
    required bool isCompleted,
  }) => _repository.postVideoProgress(
    videoId,
    lastPositionSeconds: lastPositionSeconds,
    watchPercentage: watchPercentage,
    totalWatchTimeSeconds: totalWatchTimeSeconds,
    isCompleted: isCompleted,
  );
}
