import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/channel/data/models/channel_message_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChannelRemoteDataSource {
  ChannelRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /channel` — the last 50 broadcast messages, pinned ones included.
  Future<List<ChannelMessageModel>> getMessages() async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.channel,
      queryParameters: const {'limit': 50},
    );
    final body = response.data;
    final raw = body is List
        ? body
        : (body is Map ? (body['data'] ?? body['messages']) : null);
    final list = raw is List ? raw : const [];
    return list
        .whereType<Map>()
        .map((e) => ChannelMessageModel.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}

final channelRemoteDataSourceProvider = Provider<ChannelRemoteDataSource>((
  ref,
) {
  return ChannelRemoteDataSource(ref.watch(dioClientProvider));
});
