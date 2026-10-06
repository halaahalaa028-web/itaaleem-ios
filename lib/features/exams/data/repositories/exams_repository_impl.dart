import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/exams/data/datasources/exams_remote_data_source.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/domain/entities/exam_result.dart';
import 'package:itaaleem/features/exams/domain/repositories/exams_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ExamsRepositoryImpl implements ExamsRepository {
  ExamsRepositoryImpl(this._remoteDataSource);

  final ExamsRemoteDataSource _remoteDataSource;

  @override
  Future<Result<List<ExamSummary>>> getExams({
    Map<int, String> subjects = const {},
  }) async {
    try {
      final exams = await _remoteDataSource.getAllExams(subjects);
      return Ok(exams);
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  @override
  Future<Result<List<ExamSummary>>> getSubjectExams(int subjectId) async {
    try {
      return Ok(await _remoteDataSource.getSubjectExams(subjectId));
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  @override
  Future<Result<ExamDetails>> getExamDetails(int examId) async {
    try {
      final details = await _remoteDataSource.getExamDetails(examId);
      return Ok(details);
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  @override
  Future<Result<List<ExamQuestion>>> getExamQuestions(int examId) async {
    try {
      final questions = await _remoteDataSource.getExamQuestions(examId);
      return Ok(questions);
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  @override
  Future<Result<ExamStart>> startExam(int examId) async {
    try {
      return Ok(await _remoteDataSource.startExam(examId));
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  @override
  Future<Result<ExamResult>> getAttemptReview(int attemptId) async {
    try {
      return Ok(await _remoteDataSource.getAttemptReview(attemptId));
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 || e.response?.statusCode == 404) {
        return const Err(
          UnknownFailure('مراجعة الإجابات غير متاحة لهذا الامتحان'),
        );
      }
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  @override
  Future<Result<ExamResult>> submitExam(
    int examId,
    Map<int, Object> answers, {
    int? attemptId,
    int? timeSpentSeconds,
    Set<int> booleanQuestionIds = const {},
  }) async {
    try {
      final result = await _remoteDataSource.submitExam(
        examId,
        answers,
        attemptId: attemptId,
        timeSpentSeconds: timeSpentSeconds,
        booleanQuestionIds: booleanQuestionIds,
      );
      return Ok(result);
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  @override
  Future<Result<List<ExamAttemptSummary>>> getExamResults(int examId) async {
    try {
      final results = await _remoteDataSource.getExamResults(examId);
      return Ok(results);
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  Failure _failureOf(DioException e) {
    final error = e.error;
    if (error is Failure) return error;
    return const NetworkFailure('تعذر الاتصال بالسيرفر، تحقق من الإنترنت');
  }
}

final examsRepositoryProvider = Provider<ExamsRepository>((ref) {
  final remoteDataSource = ref.watch(examsRemoteDataSourceProvider);
  return ExamsRepositoryImpl(remoteDataSource);
});
