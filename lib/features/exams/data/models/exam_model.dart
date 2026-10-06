import 'package:itaaleem/features/exams/domain/entities/exam.dart';

/// Maps `GET /exams/{id}` onto [ExamDetails]. Field names follow the same
/// snake_case + `??`-fallback convention as the rest of the app's models,
/// since the exact response shape hasn't been confirmed against the live
/// API yet.
class ExamDetailsModel extends ExamDetails {
  const ExamDetailsModel({
    required super.id,
    required super.title,
    super.description,
    super.durationMinutes,
    super.passScore,
    super.attemptsAllowed,
    super.attemptsUsed,
    super.questions,
    super.allowReview,
    super.showResultImmediately,
  });

  factory ExamDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List?) ?? const [];
    return ExamDetailsModel(
      id: _asInt(json['id']) ?? 0,
      title: (json['title'] ?? json['name'])?.toString() ?? '',
      description: json['description']?.toString(),
      durationMinutes: _asInt(json['duration_minutes'] ?? json['duration']),
      passScore: _asDouble(
        json['pass_score'] ?? json['passing_score'] ?? json['pass_percentage'],
      ),
      attemptsAllowed: _asInt(json['attempts_allowed'] ?? json['max_attempts']),
      attemptsUsed:
          _asInt(
            json['attempts_used'] ??
                json['attempts_count'] ??
                json['attempt_count'],
          ) ??
          0,
      questions: rawQuestions
          .whereType<Map<String, dynamic>>()
          .map(ExamQuestionModel.fromJson)
          .toList(),
      allowReview: asBool(json['allow_review']) ?? true,
      showResultImmediately: asBool(json['show_result_immediately']) ?? true,
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

/// `true`/`false`, `1`/`0` or `"1"`/`"true"` — Laravel sends all of them.
bool? asBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final v = value.toLowerCase();
    if (v == '1' || v == 'true') return true;
    if (v == '0' || v == 'false') return false;
  }
  return null;
}

class ExamQuestionModel extends ExamQuestion {
  const ExamQuestionModel({
    required super.id,
    required super.text,
    super.options,
    super.type,
    super.marks,
    super.explanation,
    super.imageUrl,
    super.syntheticBooleanOptions,
  });

  factory ExamQuestionModel.fromJson(Map<String, dynamic> json) {
    final rawOptions =
        (json['options'] ?? json['answers'] ?? const []) as List? ?? const [];
    // Options are either objects (`{id, text}`) or plain strings; a plain
    // string's id is its 0-based position, which is what gets submitted
    // as `selected_option`.
    final options = <ExamOption>[
      for (var i = 0; i < rawOptions.length; i++)
        if (rawOptions[i] is Map<String, dynamic>)
          ExamOptionModel.fromJson(rawOptions[i] as Map<String, dynamic>)
        else if (rawOptions[i] != null)
          ExamOptionModel(id: i, text: rawOptions[i].toString()),
    ];
    final rawType = (json['question_type'] ?? json['type'])?.toString();
    final type = switch (rawType) {
      'true_false' || 'boolean' || 'tf' => ExamQuestionType.trueFalse,
      'short_answer' || 'text' || 'essay' => ExamQuestionType.shortAnswer,
      _ => ExamQuestionType.multipleChoice,
    };
    final synthetic = type == ExamQuestionType.trueFalse && options.isEmpty;
    return ExamQuestionModel(
      id: ExamDetailsModel._asInt(json['id']) ?? 0,
      text:
          (json['question_text'] ??
                  json['question'] ??
                  json['text'] ??
                  json['title'])
              ?.toString() ??
          '',
      type: type,
      marks: ExamDetailsModel._asDouble(json['marks'] ?? json['points']) ?? 1,
      explanation: json['explanation']?.toString(),
      imageUrl: (json['image_url'] ?? json['image'])?.toString(),
      syntheticBooleanOptions: synthetic,
      options: synthetic
          ? const [
              ExamOption(id: 1, text: 'صح'),
              ExamOption(id: 0, text: 'خطأ'),
            ]
          : options,
    );
  }
}

class ExamOptionModel extends ExamOption {
  const ExamOptionModel({
    required super.id,
    required super.text,
    super.isCorrect,
  });

  factory ExamOptionModel.fromJson(Map<String, dynamic> json) {
    return ExamOptionModel(
      id: ExamDetailsModel._asInt(json['id']) ?? 0,
      text:
          (json['option_text'] ??
                  json['option'] ??
                  json['text'] ??
                  json['title'])
              ?.toString() ??
          '',
      isCorrect: asBool(json['is_correct']) ?? false,
    );
  }
}

/// `POST /exams/{id}/start` → [ExamStart].
ExamStart examStartFromJson(Map<String, dynamic> json) {
  final data = json['data'];
  final body = data is Map<String, dynamic> ? data : json;
  final rawQuestions = body['questions'];
  return ExamStart(
    attemptId: ExamDetailsModel._asInt(
      body['attempt_id'] ??
          (body['attempt'] is Map ? body['attempt']['id'] : null),
    ),
    questions: rawQuestions is List
        ? rawQuestions
              .whereType<Map<String, dynamic>>()
              .map(ExamQuestionModel.fromJson)
              .toList()
        : const [],
    durationMinutes: ExamDetailsModel._asInt(body['duration_minutes']),
    startedAt: DateTime.tryParse('${body['started_at'] ?? ''}'),
  );
}

/// Maps one item of `GET /exams/{id}/questions`'s `data` array onto
/// [ExamQuestion] — same field-name hedging as [ExamQuestionModel.fromJson]
/// above, since this endpoint's exact shape isn't confirmed either.
ExamQuestion examQuestionFromJson(Map<String, dynamic> json) =>
    ExamQuestionModel.fromJson(json);

/// Maps one item of `GET /exams/{id}/results`'s `data` array onto
/// [ExamAttemptSummary].
class ExamAttemptSummaryModel extends ExamAttemptSummary {
  const ExamAttemptSummaryModel({
    required super.id,
    required super.percentage,
    required super.isPassed,
    super.takenAt,
  });

  factory ExamAttemptSummaryModel.fromJson(Map<String, dynamic> json) {
    final percentage =
        _asDouble(
          json['percentage'] ?? json['score_percentage'] ?? json['score'],
        ) ??
        0;
    final takenAtRaw =
        (json['taken_at'] ?? json['created_at'] ?? json['submitted_at'])
            as String?;
    return ExamAttemptSummaryModel(
      id: _asInt(json['id']) ?? 0,
      percentage: percentage,
      isPassed: asBool(json['is_passed'] ?? json['passed']) ?? false,
      takenAt: takenAtRaw != null ? DateTime.tryParse(takenAtRaw) : null,
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

/// Maps one `GET /exams` list item onto [ExamSummary] — shape verified
/// live: `{id, title, subject:{id,name}, questions_count,
/// duration_minutes, pass_percentage, is_locked}`.
class ExamSummaryModel extends ExamSummary {
  const ExamSummaryModel({
    required super.id,
    required super.title,
    super.subjectName,
    required super.questionsCount,
    super.durationMinutes,
    required super.passPercentage,
    super.isLocked,
  });

  factory ExamSummaryModel.fromJson(Map<String, dynamic> raw) {
    // Lecture/pivot rows wrap the exam: `{id: <pivot id>, exam_id, exam: {…}}`
    // — the exam's own fields (and id) live in the nested object.
    final nested = raw['exam'];
    final json = nested is Map
        ? {...raw, ...Map<String, dynamic>.from(nested)}
        : raw;
    final subject = json['subject'];
    return ExamSummaryModel(
      id:
          ExamDetailsModel._asInt(
            nested is Map ? nested['id'] : (raw['exam_id'] ?? raw['id']),
          ) ??
          ExamDetailsModel._asInt(raw['exam_id']) ??
          0,
      title: (json['title'] ?? json['name'])?.toString() ?? '',
      subjectName: subject is Map ? subject['name']?.toString() : null,
      questionsCount:
          ExamDetailsModel._asInt(
            json['questions_count'] ?? json['total_questions'],
          ) ??
          0,
      durationMinutes: ExamDetailsModel._asInt(
        json['duration_minutes'] ?? json['duration'],
      ),
      passPercentage:
          ExamDetailsModel._asInt(
            json['pass_percentage'] ?? json['pass_score'],
          ) ??
          60,
      isLocked: json['is_locked'] == true,
    );
  }

  ExamSummaryModel withSubjectName(String name) => ExamSummaryModel(
    id: id,
    title: title,
    subjectName: name,
    questionsCount: questionsCount,
    durationMinutes: durationMinutes,
    passPercentage: passPercentage,
    isLocked: isLocked,
  );
}
