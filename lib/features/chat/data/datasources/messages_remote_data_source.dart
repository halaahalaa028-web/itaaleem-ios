import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/chat/domain/entities/message_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

MessageModel _messageFromJson(Map<String, dynamic> json) {
  final createdAtRaw = json['created_at'] as String?;
  final readAtRaw = json['read_at'] as String?;
  return MessageModel(
    id: json['id']?.toString() ?? 'msg-${DateTime.now().microsecondsSinceEpoch}',
    body: json['body'] as String? ?? '',
    senderId: 0,
    receiverId: 0,
    isMine: json['is_mine'] as bool? ?? false,
    createdAt: createdAtRaw != null
        ? (DateTime.tryParse(createdAtRaw) ?? DateTime.now())
        : DateTime.now(),
    readAt: readAtRaw != null ? DateTime.tryParse(readAtRaw) : null,
  );
}

/// The message list out of whichever envelope the API used: `data.items`,
/// `data.data`, `data.messages`, a bare `data: [...]`, or top-level
/// `items`/`messages`/list. (Silently reading an unrecognized shape as "no
/// messages" made the whole conversation look wiped on every reload.)
List<dynamic> _extractItems(dynamic body) {
  if (body is List) return body;
  if (body is! Map) return const [];
  final data = body['data'];
  if (data is List) return data;
  for (final source in [if (data is Map) data, body]) {
    for (final key in const ['items', 'data', 'messages']) {
      final value = source[key];
      if (value is List) return value;
    }
  }
  return const [];
}

/// Raw Dio calls against `/messages` — the student<->center chat, not
/// documented in APP_SPEC.md, verified live against the backend directly.
class MessagesRemoteDataSource {
  MessagesRemoteDataSource(this._dio);

  final Dio _dio;

  /// Newest first, per the live API's own ordering — [ChatScreen]'s
  /// `reverse: true` list consumes it as-is, but the result is also
  /// defensively re-sorted client-side to guarantee that order regardless.
  Future<List<MessageModel>> getMessages() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.messages);
    if (kDebugMode) {
      debugPrint('>>> GET ${ApiEndpoints.messages} raw response: ${response.data}');
    }
    final rawList = _extractItems(response.data);
    final messages = rawList
        .whereType<Map>()
        .map((e) => _messageFromJson(e.cast<String, dynamic>()))
        .toList();
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return messages;
  }

  Future<MessageModel> sendMessage(String body) async {
    if (kDebugMode) {
      debugPrint('>>> sending message: $body');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.messages,
      data: {'body': body},
    );
    if (kDebugMode) {
      debugPrint('>>> send response: ${response.data}');
    }
    final envelope = response.data;
    final data = envelope?['data'];
    final json = data is Map<String, dynamic>
        ? data
        : (envelope != null && envelope['id'] != null ? envelope : null);
    if (json == null) {
      // The request itself succeeded (no DioException), but its response
      // didn't carry the created message back in a shape this parses —
      // an envelope this app doesn't recognize, or just a bare
      // `{"success": true}` ack with no echoed message at all. Falling
      // back to `_messageFromJson({})` would silently produce an
      // empty-body message with id "null", which looked to the student
      // like their message vanished the instant it sent (the optimistic
      // bubble gets replaced by this blank one) — echo what was actually
      // just sent instead of losing it.
      if (kDebugMode) {
        debugPrint(
          '>>> send response has no usable message shape — echoing sent text locally',
        );
      }
      return MessageModel(
        id: 'sent-${DateTime.now().microsecondsSinceEpoch}',
        body: body,
        senderId: 0,
        receiverId: 0,
        isMine: true,
        createdAt: DateTime.now(),
      );
    }
    return _messageFromJson(json);
  }
}

final messagesRemoteDataSourceProvider = Provider<MessagesRemoteDataSource>((
  ref,
) {
  final dio = ref.watch(dioClientProvider);
  return MessagesRemoteDataSource(dio);
});
