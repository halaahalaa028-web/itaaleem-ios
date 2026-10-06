import 'package:itaaleem/features/ai/domain/entities/ai_answer.dart';

/// Maps `POST /ai/ask`'s response onto [AiAnswer] — parsed defensively
/// (several possible key names) since the exact response shape isn't
/// confirmed yet against the live API.
class AiAnswerModel extends AiAnswer {
  const AiAnswerModel({required super.answer, super.remainingQuestions});

  factory AiAnswerModel.fromJson(Map<String, dynamic> json) {
    final body = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final answer =
        body['answer'] ?? body['message'] ?? body['response'] ?? body['reply'];
    final remaining =
        body['remaining_questions'] ??
        body['remaining'] ??
        body['questions_remaining'] ??
        body['remaining_today'];
    return AiAnswerModel(
      answer: answer is String && answer.isNotEmpty
          ? answer
          : 'تعذر الحصول على إجابة، حاول مرة أخرى',
      remainingQuestions: remaining is num ? remaining.toInt() : null,
    );
  }
}
