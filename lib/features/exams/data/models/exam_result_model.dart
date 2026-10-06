import 'package:itaaleem/features/exams/data/models/exam_model.dart';
import 'package:itaaleem/features/exams/domain/entities/exam_result.dart';

/// Maps `POST /exams/{id}/submit`'s response (and
/// `GET /exam-attempts/{id}/review`'s) onto [ExamResult].
class ExamResultModel extends ExamResult {
  const ExamResultModel({
    required super.score,
    required super.totalScore,
    required super.percentage,
    required super.isPassed,
    super.questionResults,
    super.attemptId,
    super.timeSpentSeconds,
    super.allowReview,
    super.isPending,
  });

  factory ExamResultModel.fromJson(Map<String, dynamic> json) {
    // Some servers nest the attempt (`{attempt: {...}, results: [...]}`).
    final attempt = json['attempt'] is Map<String, dynamic>
        ? json['attempt'] as Map<String, dynamic>
        : const <String, dynamic>{};
    Object? pick(String key) => json[key] ?? attempt[key];

    final score = _asDouble(pick('score') ?? json['total_correct']) ?? 0;
    final totalScore =
        _asDouble(
          pick('total_score') ??
              pick('total_marks') ??
              json['total'] ??
              json['total_questions'],
        ) ??
        0;
    final percentage =
        _asDouble(pick('percentage') ?? json['score_percentage']) ??
        (totalScore > 0 ? (score / totalScore * 100) : 0);
    final rawAnswers = json['answers'] ?? json['results'] ?? json['details'];
    final rawResults = rawAnswers is List ? rawAnswers : const [];
    return ExamResultModel(
      score: score,
      totalScore: totalScore,
      percentage: percentage,
      isPassed: asBool(pick('is_passed') ?? pick('passed')) ?? false,
      attemptId: _asInt(json['attempt_id'] ?? attempt['id']),
      timeSpentSeconds: _asInt(pick('time_spent_seconds')),
      allowReview: asBool(json['allow_review']) ?? true,
      isPending:
          pick('score') == null &&
          pick('percentage') == null &&
          pick('passed') == null &&
          pick('is_passed') == null &&
          json['total_correct'] == null &&
          json['score_percentage'] == null,
      questionResults: rawResults
          .whereType<Map>()
          .map((e) => _questionResultFromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  static ExamQuestionResult _questionResultFromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final options = rawOptions is List
        ? rawOptions
              .whereType<Map<String, dynamic>>()
              .map(ExamOptionModel.fromJson)
              .toList()
        : const <ExamOptionModel>[];
    final correctFromOptions = options.where((o) => o.isCorrect).firstOrNull;
    return ExamQuestionResult(
      questionId: _asInt(json['question_id'] ?? json['id']) ?? 0,
      isCorrect: asBool(json['is_correct'] ?? json['correct']) ?? false,
      selectedOptionId: _asInt(
        json['selected_option'] ?? json['selected_option_id'],
      ),
      correctOptionId:
          _asInt(json['correct_option'] ?? json['correct_option_id']) ??
          correctFromOptions?.id,
      answerText: json['answer_text']?.toString(),
      questionText:
          (json['question_text'] ??
                  (json['question'] is Map
                      ? json['question']['question_text']
                      : json['question']))
              ?.toString(),
      explanation: json['explanation']?.toString(),
      marksObtained: _asDouble(json['marks_obtained']),
      options: options,
    );
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
