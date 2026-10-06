import 'package:itaaleem/features/exams/domain/entities/exam.dart';

/// Response shape of `POST /exams/{id}/submit` (and of
/// `GET /exam-attempts/{id}/review`).
class ExamResult {
  const ExamResult({
    required this.score,
    required this.totalScore,
    required this.percentage,
    required this.isPassed,
    this.questionResults = const [],
    this.attemptId,
    this.timeSpentSeconds,
    this.allowReview = true,
    this.isPending = false,
  });

  final double score;
  final double totalScore;

  /// 0-100.
  final double percentage;
  final bool isPassed;

  /// Per-question correct/incorrect breakdown, when the API sends one.
  /// Empty when it doesn't — [ExamResultScreen] just skips that section.
  final List<ExamQuestionResult> questionResults;

  /// The attempt this result belongs to, when the server tracks attempts —
  /// lets the review screen fetch `GET /exam-attempts/{id}/review`.
  final int? attemptId;
  final int? timeSpentSeconds;

  /// The exam's `allow_review`.
  final bool allowReview;

  /// Submitted, but the exam doesn't show results immediately
  /// (`show_result_immediately = false`) — the server sent no score.
  final bool isPending;
}

/// One question's outcome, as part of [ExamResult.questionResults].
class ExamQuestionResult {
  const ExamQuestionResult({
    required this.questionId,
    required this.isCorrect,
    this.selectedOptionId,
    this.correctOptionId,
    this.answerText,
    this.questionText,
    this.explanation,
    this.marksObtained,
    this.options = const [],
  });

  final int questionId;
  final bool isCorrect;
  final int? selectedOptionId;
  final int? correctOptionId;

  /// The student's text for a short-answer question.
  final String? answerText;

  /// Review payloads carry the question itself, so a review opened from an
  /// old attempt doesn't need the questions separately.
  final String? questionText;
  final String? explanation;
  final double? marksObtained;

  /// The options with their real `is_correct` (review only).
  final List<ExamOption> options;
}
