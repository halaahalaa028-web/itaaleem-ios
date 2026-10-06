import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/data/models/exam_model.dart';
import 'package:itaaleem/features/exams/data/models/exam_result_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Every exam request needs a real id — an unparsed `0` would hit
/// `/exams/0/...`, 404, and (repeated) trip the server's rate limit.
void _ensureValidExamId(int examId) {
  if (examId <= 0) {
    if (kDebugMode) debugPrint('>>> exam request blocked: invalid id $examId');
    throw const ValidationFailure('لا يمكن فتح هذا الامتحان');
  }
}

class ExamsRemoteDataSource {
  ExamsRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /exams` — optionally scoped with `?subject_id=` (the server's
  /// working filter; it's a *subject* id, not a course id).
  Future<List<ExamSummaryModel>> getExams({int? subjectId}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.exams,
      queryParameters: {'subject_id': ?subjectId},
    );
    if (kDebugMode) {
      debugPrint(
        '>>> GET ${ApiEndpoints.exams} subject_id=$subjectId raw response: ${response.data}',
      );
    }
    return _parseSummaries(_extractList(response.data, 'exams'));
  }

  /// One lecture's own exams: `GET /lectures/{id}/exams`; only if that
  /// route fails (e.g. 404 on an older server), `GET /exams?lecture_id=`.
  /// `null` when neither gives a lecture-scoped answer — the caller then
  /// shows the subject's exams.
  Future<List<ExamSummaryModel>?> getLectureExams(int lectureId) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.lectureExams(lectureId),
      );
      if (kDebugMode) {
        debugPrint(
          '>>> GET ${ApiEndpoints.lectureExams(lectureId)} raw response: '
          '${response.data}',
        );
      }
      // The route exists → its answer is authoritative, even when empty.
      return _parseSummaries(
        _extractList(response.data, 'exams'),
      ).where((e) => e.id > 0).toList();
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '>>> GET ${ApiEndpoints.lectureExams(lectureId)} failed '
          '(falling back to ?lecture_id=): '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}',
        );
      }
    }
    try {
      final response = await _dio.get<dynamic>(
        ApiEndpoints.exams,
        queryParameters: {'lecture_id': lectureId},
      );
      if (kDebugMode) {
        debugPrint(
          '>>> GET ${ApiEndpoints.exams}?lecture_id=$lectureId raw response: '
          '${response.data}',
        );
      }
      final body = response.data;
      final raw = _extractList(body, 'exams');
      // A server that ignores `lecture_id` returns every exam: reject the
      // list only if an item explicitly names a *different* lecture.
      // (Items without a lecture field are accepted.)
      final foreign = raw.whereType<Map>().any((e) {
        final owner = e['lecture_id'] ?? e['lesson_id'];
        return owner != null && '$owner' != '$lectureId';
      });
      final list = _parseSummaries(raw).where((e) => e.id > 0).toList();
      if (list.isNotEmpty && !foreign) return list;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('>>> exams?lecture_id=$lectureId failed: $e');
      }
    }
    return null;
  }

  /// A subject's exams: `GET /exams?subject_id=` first, then
  /// `GET /courses/{subject}/exams` when that comes back empty or fails.
  Future<List<ExamSummaryModel>> getSubjectExams(int subjectId) async {
    try {
      final exams = await getExams(subjectId: subjectId);
      if (exams.isNotEmpty) return exams;
    } on DioException catch (e) {
      if (kDebugMode) debugPrint('>>> exams?subject_id=$subjectId failed: $e');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.courseExams(subjectId),
    );
    return _parseSummaries(_extractList(response.data, 'exams'));
  }

  /// Every exam the student can see: the unscoped list plus each subject's
  /// own list, merged and de-duplicated by id. A single failing call is
  /// ignored; the error only surfaces when *every* call failed.
  Future<List<ExamSummaryModel>> getAllExams(Map<int, String> subjects) async {
    Object? firstError;
    Future<List<ExamSummaryModel>> guarded(
      Future<List<ExamSummaryModel>> Function() call,
    ) async {
      try {
        return await call();
      } catch (e) {
        firstError ??= e;
        return const [];
      }
    }

    final lists = await Future.wait([
      guarded(() => getExams()),
      for (final id in subjects.keys) guarded(() => getSubjectExams(id)),
    ]);
    final byId = <int, ExamSummaryModel>{};
    for (var i = 0; i < lists.length; i++) {
      // lists[0] is the unscoped call; lists[i] (i > 0) belongs to a subject.
      final subjectName = i == 0 ? null : subjects.values.elementAt(i - 1);
      for (final exam in lists[i]) {
        final existing = byId[exam.id];
        if (existing == null || existing.subjectName == null) {
          byId[exam.id] = exam.subjectName == null && subjectName != null
              ? exam.withSubjectName(subjectName)
              : exam;
        }
      }
    }
    if (byId.isEmpty && firstError != null) throw firstError!;
    return byId.values.toList();
  }

  List<ExamSummaryModel> _parseSummaries(List<dynamic> raw) {
    final out = <ExamSummaryModel>[];
    for (final e in raw) {
      if (e is! Map<String, dynamic>) continue;
      try {
        out.add(ExamSummaryModel.fromJson(e));
      } catch (err) {
        if (kDebugMode) debugPrint('>>> skipped unparsable exam: $err');
      }
    }
    return out;
  }

  Future<ExamDetailsModel> getExamDetails(int examId) async {
    _ensureValidExamId(examId);
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.examDetails(examId),
    );
    if (kDebugMode) {
      debugPrint('>>> GET /exams/$examId raw response: ${response.data}');
    }
    final data = response.data?['data'];
    final body = data is Map<String, dynamic>
        ? data
        : (response.data ?? const <String, dynamic>{});
    return ExamDetailsModel.fromJson(body);
  }

  /// `GET /exams/{id}/questions` — the exam's questions, without the
  /// correct answer.
  Future<List<ExamQuestion>> getExamQuestions(int examId) async {
    _ensureValidExamId(examId);
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.examQuestions(examId),
    );
    if (kDebugMode) {
      debugPrint(
        '>>> GET ${ApiEndpoints.examQuestions(examId)} raw response: ${response.data}',
      );
    }
    final rawList = _extractList(response.data, 'questions');
    return rawList
        .map((e) => examQuestionFromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /exams/{id}/start`, falling back to `GET /exams/{id}/questions`
  /// (no attempt id) on servers that don't have it yet.
  Future<ExamStart> startExam(int examId) async {
    _ensureValidExamId(examId);
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.examStart(examId),
      );
      if (kDebugMode) {
        debugPrint(
          '>>> POST ${ApiEndpoints.examStart(examId)}: ${response.data}',
        );
      }
      final start = examStartFromJson(response.data ?? const {});
      if (start.questions.isNotEmpty) return start;
      // Attempt opened but no questions in the body — fetch them.
      return ExamStart(
        attemptId: start.attemptId,
        durationMinutes: start.durationMinutes,
        startedAt: start.startedAt,
        questions: await getExamQuestions(examId),
      );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code != 404 && code != 405) rethrow;
      return ExamStart(questions: await getExamQuestions(examId));
    }
  }

  /// `POST /exams/{id}/submit` — [answers] maps question id to either the
  /// selected option id (`int`) or the typed answer (`String`).
  ///
  /// Each answer is sent under both the current (`selected_option`) and the
  /// newer (`selected_option_id`) key, so either server version reads it.
  Future<ExamResultModel> submitExam(
    int examId,
    Map<int, Object> answers, {
    int? attemptId,
    int? timeSpentSeconds,
    Set<int> booleanQuestionIds = const {},
  }) async {
    _ensureValidExamId(examId);
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.examSubmit(examId),
      data: {
        'attempt_id': ?attemptId,
        'time_spent_seconds': ?timeSpentSeconds,
        'answers': [
          for (final entry in answers.entries)
            if (entry.value is int)
              {
                'question_id': entry.key,
                'selected_option': entry.value,
                'selected_option_id': entry.value,
                // A true/false question without real options: the choice
                // itself is the answer.
                if (booleanQuestionIds.contains(entry.key))
                  'answer_text': entry.value == 1 ? 'true' : 'false',
              }
            else
              {'question_id': entry.key, 'answer_text': '${entry.value}'},
        ],
      },
    );
    if (kDebugMode) {
      debugPrint(
        '>>> POST ${ApiEndpoints.examSubmit(examId)} raw response: ${response.data}',
      );
    }
    final data = response.data?['data'];
    final body = data is Map<String, dynamic>
        ? data
        : (response.data ?? const <String, dynamic>{});
    return ExamResultModel.fromJson(body);
  }

  /// `GET /exam-attempts/{id}/review`.
  Future<ExamResultModel> getAttemptReview(int attemptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.examAttemptReview(attemptId),
    );
    final data = response.data?['data'];
    final body = data is Map<String, dynamic>
        ? data
        : (response.data ?? const <String, dynamic>{});
    return ExamResultModel.fromJson(body);
  }

  /// `GET /exams/{id}/results` — this student's past attempts on the exam.
  Future<List<ExamAttemptSummaryModel>> getExamResults(int examId) async {
    // An unparsed id would call `/exams/0/results` — never hit the API.
    if (examId <= 0) {
      if (kDebugMode) {
        debugPrint('>>> exam results skipped: invalid id $examId');
      }
      return const [];
    }
    Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.examResults(examId),
      );
    } on DioException catch (e) {
      // Newer backends expose the singular `/result` instead.
      if (e.response?.statusCode != 404) rethrow;
      response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.examResult(examId),
      );
    }
    if (kDebugMode) {
      debugPrint('>>> GET exam $examId results raw response: ${response.data}');
    }
    var rawList = _extractList(response.data, 'results');
    if (rawList.isEmpty) {
      // A single-attempt body: `{data: {score, ...}}`.
      final data = response.data?['data'];
      if (data is Map<String, dynamic> && data.containsKey('score')) {
        rawList = [data];
      }
    }
    return rawList
        .map((e) => ExamAttemptSummaryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Pulls a list out of a JSON response body that may wrap it under `data`
/// (`{"data": [...]}` or the paginated `{"data": {"items": [...]}}`), or
/// bare under [key] — the same defensive fallback chain used by
/// `SubjectsRemoteDataSource`/`CentersRemoteDataSource`, since `GET
/// /centers?code=` has already been confirmed live to use the bare-key
/// shape instead of a `data` envelope.
List<dynamic> _extractList(Map<String, dynamic>? body, String key) {
  final envelope = body?['data'];
  return _asList(body?[key]) ??
      _asList(envelope) ??
      _asList(envelope is Map<String, dynamic> ? envelope['items'] : null) ??
      const [];
}

List<dynamic>? _asList(Object? value) => value is List ? value : null;

final examsRemoteDataSourceProvider = Provider<ExamsRemoteDataSource>((ref) {
  final dio = ref.watch(dioClientProvider);
  return ExamsRemoteDataSource(dio);
});
