import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/ai/domain/entities/ai_answer.dart';
import 'package:itaaleem/features/ai/domain/repositories/ai_repository.dart';

class AskAiUseCase {
  const AskAiUseCase(this._repository);

  final AiRepository _repository;

  Future<Result<AiAnswer>> call(String question, {int? courseId}) =>
      _repository.ask(question, courseId: courseId);
}
