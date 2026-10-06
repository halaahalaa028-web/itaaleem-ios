import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/activation/data/datasources/activation_remote_data_source.dart';
import 'package:itaaleem/features/activation/domain/repositories/activation_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivationRepositoryImpl implements ActivationRepository {
  ActivationRepositoryImpl(this._remoteDataSource);

  final ActivationRemoteDataSource _remoteDataSource;

  @override
  Future<Result<String>> redeem(String code) async {
    try {
      final message = await _remoteDataSource.redeem(code);
      return Ok(message);
    } on DioException catch (e) {
      final error = e.error;
      final failure = error is Failure
          ? error
          : const NetworkFailure(
              'تعذر الاتصال بالسيرفر، تحقق من الإنترنت',
            );
      return Err(failure);
    } catch (_) {
      return const Err(
        UnknownFailure('حدث خطأ ما، حاول مرة أخرى'),
      );
    }
  }
}

final activationRepositoryProvider = Provider<ActivationRepository>((ref) {
  final remoteDataSource = ref.watch(activationRemoteDataSourceProvider);
  return ActivationRepositoryImpl(remoteDataSource);
});
