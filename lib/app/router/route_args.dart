import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/entities/exam_result.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';

/// `state.extra` payloads for the GoRouter routes that replaced the old
/// imperative `Navigator.push(MaterialPageRoute(...))` calls. Routes pushed
/// straight onto the Navigator aren't tracked by GoRouter and can vanish when
/// it reconciles its page stack (a black screen on back), so every screen is
/// opened with `context.push(path, extra: ...)` instead.

class LessonPdfArgs {
  const LessonPdfArgs({
    required this.title,
    required this.pdfUrl,
    this.downloadable = false,
  });

  final String title;
  final String? pdfUrl;

  /// Whether the download button is offered (the API's `is_downloadable`).
  final bool downloadable;
}

class LessonAttachmentsArgs {
  const LessonAttachmentsArgs({required this.lesson, required this.subjectId});

  final SubjectLesson lesson;
  final int subjectId;
}

class ExamTakingArgs {
  const ExamTakingArgs({
    required this.examId,
    required this.title,
    required this.durationMinutes,
    required this.questions,
    this.passPercentage,
    this.attemptId,
    this.startedAt,
    this.allowReview = true,
  });

  final int? examId;
  final String title;
  final int? durationMinutes;
  final List<ExamQuestion> questions;
  final int? passPercentage;

  /// From `POST /exams/{id}/start`, when the server tracks attempts.
  final int? attemptId;
  final DateTime? startedAt;
  final bool allowReview;
}

class ExamResultArgs {
  const ExamResultArgs({
    required this.result,
    this.questions = const [],
    this.answers = const {},
    this.title,
    this.allowReview = true,
  });

  final ExamResult result;
  final List<ExamQuestion> questions;

  /// What the student answered (option id or text), for the review screen.
  final Map<int, Object> answers;
  final String? title;
  final bool allowReview;
}

/// Review of an attempt: either everything is already at hand ([result] with
/// [questions]/[answers] right after submitting), or only [attemptId] (an
/// older attempt) and the screen fetches `GET /exam-attempts/{id}/review`.
class ExamReviewArgs {
  const ExamReviewArgs({
    this.title,
    this.result,
    this.questions = const [],
    this.answers = const {},
    this.attemptId,
  });

  final String? title;
  final ExamResult? result;
  final List<ExamQuestion> questions;
  final Map<int, Object> answers;
  final int? attemptId;
}
