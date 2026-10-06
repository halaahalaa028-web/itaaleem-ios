import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/update/data/datasources/update_remote_data_source.dart';
import 'package:itaaleem/features/update/domain/entities/app_version_info.dart';
import 'package:itaaleem/features/update/domain/repositories/update_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateRepositoryImpl implements UpdateRepository {
  UpdateRepositoryImpl(this._remoteDataSource);

  final UpdateRemoteDataSource _remoteDataSource;

  @override
  Future<Result<AppVersionInfo>> getAppVersion() async {
    try {
      final info = await _remoteDataSource.getAppVersion();
      return Ok(info);
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

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  final remoteDataSource = ref.watch(updateRemoteDataSourceProvider);
  return UpdateRepositoryImpl(remoteDataSource);
});
