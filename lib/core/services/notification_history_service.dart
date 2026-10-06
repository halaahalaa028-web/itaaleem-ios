import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _historyKey = 'push_notification_history';

/// Capped so a long-lived install never grows this file without bound —
/// only the most recent [_maxStored] pushes are kept.
const _maxStored = 100;

/// One push notification, recorded locally the moment it's received (or
/// tapped open) via FCM — there is no `GET /notifications` endpoint on the
/// backend, so this local log is the only history the notifications screen
/// has. Local-only: resets on reinstall, never synced across devices.
class PushNotificationRecord {
  const PushNotificationRecord({
    required this.id,
    required this.title,
    required this.receivedAt,
    this.body,
  });

  /// FCM's `RemoteMessage.messageId` when available — lets [NotificationHistoryService.add]
  /// skip a duplicate save when the same push is observed twice (e.g. once
  /// by the background handler on arrival, again via `onMessageOpenedApp`
  /// when the user taps it).
  final String id;
  final String title;
  final String? body;
  final DateTime receivedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'receivedAt': receivedAt.toIso8601String(),
  };

  factory PushNotificationRecord.fromJson(Map<String, dynamic> json) {
    return PushNotificationRecord(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String?,
      receivedAt: DateTime.parse(json['receivedAt'] as String),
    );
  }
}

class NotificationHistoryService {
  Future<void> add(PushNotificationRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAll(prefs);
    if (all.any((r) => r.id == record.id)) return;
    all.insert(0, record);
    if (all.length > _maxStored) all.removeRange(_maxStored, all.length);
    await prefs.setString(
      _historyKey,
      jsonEncode(all.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> remove(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAll(prefs)..removeWhere((r) => r.id == id);
    await prefs.setString(
      _historyKey,
      jsonEncode(all.map((r) => r.toJson()).toList()),
    );
  }

  Future<List<PushNotificationRecord>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _readAll(prefs);
    all.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return all;
  }

  Future<List<PushNotificationRecord>> _readAll(SharedPreferences prefs) async {
    final raw = prefs.getString(_historyKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => PushNotificationRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}

final notificationHistoryServiceProvider = Provider<NotificationHistoryService>(
  (ref) => NotificationHistoryService(),
);

/// The full locally-stored push history, newest first — watched by
/// [NotificationsScreen] and invalidated whenever a new push is saved.
final notificationHistoryProvider = FutureProvider<List<PushNotificationRecord>>(
  (ref) => ref.watch(notificationHistoryServiceProvider).getAll(),
);
