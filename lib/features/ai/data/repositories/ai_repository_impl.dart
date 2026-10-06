import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/ai/data/datasources/ai_remote_data_source.dart';
import 'package:itaaleem/features/ai/domain/entities/ai_answer.dart';
import 'package:itaaleem/features/ai/domain/repositories/ai_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiRepositoryImpl implements AiRepository {
  AiRepositoryImpl(this._remoteDataSource);

  final AiRemoteDataSource _remoteDataSource;

  @override
  Future<Result<AiAnswer>> ask(String question, {int? courseId}) async {
    try {
      final answer = await _remoteDataSource.ask(question, courseId: courseId);
      return Ok(answer);
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  Failure _failureOf(DioException e) {
    final error = e.error;
    if (error is Failure) return error;
    return const NetworkFailure('تعذر الاتصال، تحقق من الإنترنت وحاول مرة أخرى');
  }
}

final aiRepositoryProvider = Provider<AiRepository>((ref) {
  return AiRepositoryImpl(ref.watch(aiRemoteDataSourceProvider));
});
