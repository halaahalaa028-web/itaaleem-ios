import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/update/data/models/app_version_info_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateRemoteDataSource {
  UpdateRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AppVersionInfoModel> getAppVersion() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.appVersion,
      options: skipAuthOptions,
    );
    final data = response.data?['data'];
    final body = data is Map<String, dynamic> ? data : (response.data ?? const <String, dynamic>{});
    return AppVersionInfoModel.fromJson(body);
  }
}

final updateRemoteDataSourceProvider = Provider<UpdateRemoteDataSource>((
  ref,
) {
  return UpdateRemoteDataSource(ref.watch(dioClientProvider));
});
