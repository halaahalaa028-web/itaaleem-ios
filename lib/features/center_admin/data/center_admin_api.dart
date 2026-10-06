import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';

/// Raw HTTP for the center-admin dashboard. Every path is relative to
/// [ApiEndpoints.centerAdmin] (`/center-admin`) — the server scopes every
/// response to the admin's own center from the auth token, so the app never
/// sends a center id. Logs every response in debug builds.
class CenterAdminApi {
  CenterAdminApi(this._dio);

  final Dio _dio;

  String _url(String path) =>
      '${ApiEndpoints.centerAdmin}/${path.replaceFirst(RegExp('^/'), '')}';

  Future<Object?> get(String path, {Map<String, dynamic>? query}) => _send(
    'GET',
    path,
    () => _dio.get<dynamic>(_url(path), queryParameters: query),
  );

  Future<Object?> post(String path, [Object? data]) =>
      _send('POST', path, () => _dio.post<dynamic>(_url(path), data: data));

  Future<Object?> put(String path, [Object? data]) =>
      _send('PUT', path, () => _dio.put<dynamic>(_url(path), data: data));

  Future<Object?> delete(String path) =>
      _send('DELETE', path, () => _dio.delete<dynamic>(_url(path)));

  Future<Object?> _send(
    String method,
    String path,
    Future<Response<dynamic>> Function() call,
  ) async {
    try {
      final response = await call();
      if (kDebugMode) {
        debugPrint(
          '>>> [CenterAdmin] $method ${_url(path)} '
          '${response.statusCode}: ${response.data}',
        );
      }
      return response.data;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '>>> [CenterAdmin] $method ${_url(path)} FAILED '
          '${e.response?.statusCode}: ${e.response?.data ?? e.message}',
        );
      }
      rethrow;
    }
  }
}

final centerAdminApiProvider = Provider<CenterAdminApi>(
  (ref) => CenterAdminApi(ref.watch(dioClientProvider)),
);
