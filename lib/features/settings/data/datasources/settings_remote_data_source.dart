import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/settings/data/models/app_settings_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsRemoteDataSource {
  SettingsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AppSettingsModel> getAppSettings() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.publicSettings,
      options: skipAuthOptions,
    );
    final data = response.data?['data'];
    final body = data is Map<String, dynamic> ? data : (response.data ?? const <String, dynamic>{});
    return AppSettingsModel.fromJson(body);
  }
}

final settingsRemoteDataSourceProvider = Provider<SettingsRemoteDataSource>((
  ref,
) {
  return SettingsRemoteDataSource(ref.watch(dioClientProvider));
});
