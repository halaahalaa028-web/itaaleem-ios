/// Full exam shape from `GET /exams/{id}` — questions never carry the
/// correct answer, only the option list the student picks from.
class ExamDetails {
  const ExamDetails({
    required this.id,
    required this.title,
    this.description,
    this.durationMinutes,
    this.passScore,
    this.attemptsAllowed,
    this.attemptsUsed = 0,
    this.questions = const [],
    this.allowReview = true,
    this.showResultImmediately = true,
  });

  final int id;
  final String title;
  final String? description;

  /// Null means untimed — the taking screen shows no countdown.
  final int? durationMinutes;

  /// The minimum score (same unit as [ExamResult.percentage], 0-100) needed
  /// to pass.
  final double? passScore;

  /// Null means unlimited attempts.
  final int? attemptsAllowed;
  final int attemptsUsed;
  final List<ExamQuestion> questions;

  /// The exam's `allow_review` — whether answers can be reviewed afterwards.
  final bool allowReview;

  /// The exam's `show_result_immediately`.
  final bool showResultImmediately;

  int get questionsCount => questions.length;

  bool get hasAttemptsLeft =>
      attemptsAllowed == null || attemptsUsed < attemptsAllowed!;
}

/// Question kinds the taking screen can render.
abstract final class ExamQuestionType {
  static const multipleChoice = 'multiple_choice';
  static const trueFalse = 'true_false';
  static const shortAnswer = 'short_answer';
}

class ExamQuestion {
  const ExamQuestion({
    required this.id,
    required this.text,
    this.options = const [],
    this.type = ExamQuestionType.multipleChoice,
    this.marks = 1,
    this.explanation,
    this.imageUrl,
    this.syntheticBooleanOptions = false,
  });

  final int id;
  final String text;
  final List<ExamOption> options;

  /// One of [ExamQuestionType].
  final String type;
  final double marks;

  /// Why the correct answer is correct — only sent for review.
  final String? explanation;
  final String? imageUrl;

  /// A true/false question the API sent without its own options: the app
  /// shows "صح"/"خطأ" (ids 1/0) and submits the choice as
  /// `answer_text: "true"/"false"` as well.
  final bool syntheticBooleanOptions;

  bool get isShortAnswer => type == ExamQuestionType.shortAnswer;
  bool get isTrueFalse => type == ExamQuestionType.trueFalse;
}

class ExamOption {
  const ExamOption({
    required this.id,
    required this.text,
    this.isCorrect = false,
  });

  final int id;
  final String text;
  final bool isCorrect;
}

/// A started attempt: `POST /exams/{id}/start`, or — on servers without it —
/// just the questions from `GET /exams/{id}/questions` ([attemptId] null).
class ExamStart {
  const ExamStart({
    required this.questions,
    this.attemptId,
    this.durationMinutes,
    this.startedAt,
  });

  final int? attemptId;
  final List<ExamQuestion> questions;

  /// Overrides the exam's own duration when the server sends one.
  final int? durationMinutes;

  /// Server start time — the countdown runs from here, so leaving and
  /// re-entering can't buy extra time.
  final DateTime? startedAt;
}

/// One past attempt from `GET /exams/{id}/results`.
class ExamAttemptSummary {
  const ExamAttemptSummary({
    required this.id,
    required this.percentage,
    required this.isPassed,
    this.takenAt,
  });

  final int id;

  /// 0-100.
  final double percentage;
  final bool isPassed;
  final DateTime? takenAt;
}

/// One item of `GET /exams` — the joined center/grade's exams across every
/// subject. Not documented in APP_SPEC.md, verified live.
class ExamSummary {
  const ExamSummary({
    required this.id,
    required this.title,
    this.subjectName,
    required this.questionsCount,
    this.durationMinutes,
    required this.passPercentage,
    this.isLocked = false,
  });

  final int id;
  final String title;
  final String? subjectName;
  final int questionsCount;
  final int? durationMinutes;
  final int passPercentage;
  final bool isLocked;
}
