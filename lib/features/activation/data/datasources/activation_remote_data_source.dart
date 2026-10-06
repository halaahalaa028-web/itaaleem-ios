import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ActivationRemoteDataSource {
  ActivationRemoteDataSource(this._dio);

  final Dio _dio;

  /// Returns the API's `message` field (per the `{success, message, data}`
  /// envelope) so the UI can show the server's own confirmation text.
  Future<String> redeem(String code) async {
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.activateCode,
      data: {'code': code},
    );
    final message = response.data?['message'];
    // The server's own message when it's Arabic, otherwise a fixed one —
    // never raw English.
    return message is String && RegExp('[؀-ۿ]').hasMatch(message)
        ? message
        : 'تم التفعيل بنجاح';
  }
}

final activationRemoteDataSourceProvider = Provider<ActivationRemoteDataSource>(
  (ref) {
    final dio = ref.watch(dioClientProvider);
    return ActivationRemoteDataSource(dio);
  },
);
