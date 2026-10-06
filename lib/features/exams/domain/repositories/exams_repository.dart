import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/entities/exam_result.dart';

abstract interface class ExamsRepository {
  /// `GET /exams` — the joined center/grade's exams across every subject.
  ///
  /// [subjects] maps subject id to name; each subject's exams are fetched
  /// with `?subject_id=` and merged in.
  Future<Result<List<ExamSummary>>> getExams({
    Map<int, String> subjects = const {},
  });

  /// `GET /exams?subject_id=` (falling back to `/courses/{subject}/exams`).
  Future<Result<List<ExamSummary>>> getSubjectExams(int subjectId);

  /// `GET /exams/{id}` — questions without their correct answers.
  Future<Result<ExamDetails>> getExamDetails(int examId);

  /// `GET /exams/{id}/questions` — the exam's questions, without the
  /// correct answer.
  Future<Result<List<ExamQuestion>>> getExamQuestions(int examId);

  /// `POST /exams/{id}/start` (or just the questions on older servers).
  Future<Result<ExamStart>> startExam(int examId);

  /// `POST /exams/{id}/submit` — [answers] maps question id to the selected
  /// option id (`int`) or a typed short answer (`String`).
  Future<Result<ExamResult>> submitExam(
    int examId,
    Map<int, Object> answers, {
    int? attemptId,
    int? timeSpentSeconds,
    Set<int> booleanQuestionIds,
  });

  /// `GET /exam-attempts/{id}/review`.
  Future<Result<ExamResult>> getAttemptReview(int attemptId);

  /// `GET /exams/{id}/results` — this student's past attempts on the exam.
  Future<Result<List<ExamAttemptSummary>>> getExamResults(int examId);
}
