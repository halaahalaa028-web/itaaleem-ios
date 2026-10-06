import 'dart:async';
import 'dart:convert';

import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/chat/data/datasources/messages_remote_data_source.dart';
import 'package:itaaleem/features/chat/domain/entities/message_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _cachePrefix = 'chat_messages_';
const _maxCachedMessages = 200;

/// A locally created message that the server hasn't confirmed yet is kept for
/// at most this long (a killed app mid-send would otherwise leave it forever).
const _pendingLifetime = Duration(days: 1);

bool _isPending(MessageModel m) => m.id.startsWith('pending-');

Map<String, dynamic> _toJson(MessageModel m) => {
  'id': m.id,
  'body': m.body,
  'sender_id': m.senderId,
  'receiver_id': m.receiverId,
  'is_mine': m.isMine,
  'created_at': m.createdAt.toIso8601String(),
  'read_at': m.readAt?.toIso8601String(),
};

MessageModel _fromJson(Map<String, dynamic> j) => MessageModel(
  id: j['id'] as String,
  body: j['body'] as String? ?? '',
  senderId: j['sender_id'] as int? ?? 0,
  receiverId: j['receiver_id'] as int? ?? 0,
  isMine: j['is_mine'] as bool? ?? false,
  createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ?? DateTime.now(),
  readAt: DateTime.tryParse(j['read_at'] as String? ?? ''),
);

/// The student<->center conversation (`GET`/`POST /messages`), newest first —
/// real accounts only; [ChatScreen] renders its own local dummy conversation
/// for a demo ("دخول تجريبي") session.
///
/// Not auto-disposed: the list lives here (not in the screen's `State`), so
/// leaving and re-entering the chat shows it instantly. It is also persisted
/// to [SharedPreferences] per student, so it survives a restart and an
/// offline/failed refresh still shows the last known conversation. Messages
/// this device sent that the server's list doesn't (yet) return are merged
/// back in rather than dropped.
class ChatController extends AsyncNotifier<List<MessageModel>> {
  String _cacheKey = '${_cachePrefix}0';

  @override
  Future<List<MessageModel>> build() async {
    final (studentId, isDemo) = ref.watch(
      authControllerProvider.select(
        (s) => (s.valueOrNull?.id, s.valueOrNull?.isDemo ?? false),
      ),
    );
    if (studentId == null || isDemo) {
      if (studentId == null) unawaited(_clearAllCaches());
      return const [];
    }
    _cacheKey = '$_cachePrefix$studentId';

    final cached = await _readCache();
    if (cached.isNotEmpty) {
      // Show what we have right away; bring it up to date in the background.
      unawaited(Future<void>.delayed(Duration.zero, refresh));
      return cached;
    }
    return _fetchMerged(const []);
  }

  Future<List<MessageModel>> _fetchMerged(List<MessageModel> local) async {
    final remote = await ref.read(messagesRemoteDataSourceProvider).getMessages();
    final merged = _merge(remote, local);
    unawaited(_writeCache(merged));
    return merged;
  }

  /// Server list plus this device's own messages the server didn't return.
  List<MessageModel> _merge(List<MessageModel> remote, List<MessageModel> local) {
    final remoteIds = remote.map((m) => m.id).toSet();
    final remoteBodies = remote
        .where((m) => m.isMine)
        .map((m) => m.body.trim())
        .toList();
    final now = DateTime.now();
    final extra = <MessageModel>[];
    for (final m in local) {
      if (!m.isMine || remoteIds.contains(m.id)) continue;
      if (_isPending(m) && now.difference(m.createdAt) > _pendingLifetime) continue;
      // Same text already confirmed by the server -> it's that message.
      final index = remoteBodies.indexOf(m.body.trim());
      if (index != -1) {
        remoteBodies.removeAt(index);
        continue;
      }
      extra.add(m);
    }
    return [...remote, ...extra]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  /// Re-fetches from the server, keeping the current list if that fails.
  Future<void> refresh() async {
    final current = state.valueOrNull ?? const <MessageModel>[];
    try {
      final fresh = await _fetchMerged(current);
      state = AsyncData(fresh);
    } catch (e) {
      if (kDebugMode) debugPrint('[ChatController] refresh failed: $e');
      if (state.valueOrNull == null) state = AsyncError(e, StackTrace.current);
    }
  }

  /// Shows a just-typed message immediately (id `pending-…`) and stores it.
  void addPending(MessageModel message) => _set([message, ...?state.valueOrNull]);

  /// Swaps a pending message for the server's confirmed copy.
  void resolvePending(String pendingId, MessageModel sent) {
    _set([
      for (final m in state.valueOrNull ?? const <MessageModel>[])
        if (m.id == pendingId) sent else m,
    ]);
  }

  /// Drops a message whose send failed.
  void removePending(String pendingId) => _set([
    for (final m in state.valueOrNull ?? const <MessageModel>[])
      if (m.id != pendingId) m,
  ]);

  void _set(List<MessageModel> messages) {
    state = AsyncData(messages);
    unawaited(_writeCache(messages));
  }

  Future<List<MessageModel>> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return const [];
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (final item in list) _fromJson((item as Map).cast<String, dynamic>()),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeCache(List<MessageModel> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newest = messages.take(_maxCachedMessages).map(_toJson).toList();
      await prefs.setString(_cacheKey, jsonEncode(newest));
    } catch (_) {}
  }

  Future<void> _clearAllCaches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().where((k) => k.startsWith(_cachePrefix))) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}

final chatControllerProvider =
    AsyncNotifierProvider<ChatController, List<MessageModel>>(ChatController.new);
