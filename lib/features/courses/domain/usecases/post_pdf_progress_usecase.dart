import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/courses/domain/repositories/courses_repository.dart';

class PostPdfProgressUseCase {
  const PostPdfProgressUseCase(this._repository);

  final CoursesRepository _repository;

  Future<Result<void>> call(
    int pdfId, {
    required int lastPage,
    required double readPercentage,
  }) => _repository.postPdfProgress(
    pdfId,
    lastPage: lastPage,
    readPercentage: readPercentage,
  );
}
