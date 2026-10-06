import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/settings/data/datasources/settings_remote_data_source.dart';
import 'package:itaaleem/features/settings/domain/entities/app_settings.dart';
import 'package:itaaleem/features/settings/domain/repositories/settings_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._remoteDataSource);

  final SettingsRemoteDataSource _remoteDataSource;

  @override
  Future<Result<AppSettings>> getAppSettings() async {
    try {
      final settings = await _remoteDataSource.getAppSettings();
      return Ok(settings);
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(
        UnknownFailure('حدث خطأ ما، حاول مرة أخرى'),
      );
    }
  }

  Failure _failureOf(DioException e) {
    final error = e.error;
    if (error is Failure) return error;
    return const NetworkFailure(
      'تعذر الاتصال بالسيرفر، تحقق من الإنترنت',
    );
  }
}

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final remoteDataSource = ref.watch(settingsRemoteDataSourceProvider);
  return SettingsRepositoryImpl(remoteDataSource);
});
