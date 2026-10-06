import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/ai/domain/entities/ai_answer.dart';

abstract interface class AiRepository {
  /// `POST /ai/ask` — asks the assistant a question, optionally scoped to
  /// a course.
  Future<Result<AiAnswer>> ask(String question, {int? courseId});
}
