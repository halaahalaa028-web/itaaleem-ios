import 'dart:convert';

import 'package:itaaleem/features/notifications/domain/entities/app_notification.dart';

/// Matches both short server types (`exam`) and Laravel class names
/// (`App\Notifications\NewExamNotification`).
AppNotificationType appNotificationTypeFrom(Object? raw) {
  final value = raw?.toString().toLowerCase() ?? '';
  if (value.contains('assignment') || value.contains('homework')) {
    return AppNotificationType.assignment;
  }
  if (value.contains('exam') || value.contains('quiz')) {
    return AppNotificationType.exam;
  }
  if (value.contains('lecture') ||
      value.contains('lesson') ||
      value.contains('video')) {
    return AppNotificationType.lecture;
  }
  if (value.contains('announcement') ||
      value.contains('general') ||
      value.contains('news')) {
    return AppNotificationType.announcement;
  }
  return AppNotificationType.other;
}

String? _text(Object? raw) {
  if (raw == null) return null;
  if (raw is Map) {
    // Translatable field: `{ar: ..., en: ...}`.
    return _text(raw['ar'] ?? raw['en'] ?? raw.values.firstOrNull);
  }
  final value = raw.toString().trim();
  return value.isEmpty ? null : value;
}

Map<String, dynamic> _map(Object? raw) {
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String && raw.trim().startsWith('{')) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
  }
  return const {};
}

DateTime? _date(Object? raw) {
  if (raw == null) return null;
  if (raw is num) {
    final ms = raw > 1e12 ? raw.toInt() : raw.toInt() * 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }
  return DateTime.tryParse(raw.toString())?.toLocal();
}

/// Tolerates the flat shape (`{id, title, body, type, read_at, created_at}`)
/// and Laravel's database-notification shape, where the content lives under
/// `data` (`{id: uuid, type: 'App\\...', data: {title, body, ...}, read_at}`).
AppNotification appNotificationFromJson(Map<String, dynamic> json) {
  final data = _map(json['data']);
  final readAt = _date(json['read_at']);
  final isRead =
      readAt != null ||
      json['is_read'] == true ||
      json['is_read'] == 1 ||
      json['read'] == true;
  final title =
      _text(json['title']) ??
      _text(data['title']) ??
      _text(data['subject']) ??
      _text(json['message']) ??
      _text(data['message']) ??
      _text(json['body']) ??
      _text(data['body']) ??
      'إشعار جديد';
  var body =
      _text(json['body']) ??
      _text(json['message']) ??
      _text(json['content']) ??
      _text(data['body']) ??
      _text(data['message']) ??
      _text(data['content']);
  if (body == title) body = null;

  return AppNotification(
    id: json['id']?.toString() ?? '',
    title: title,
    body: body,
    type: appNotificationTypeFrom(
      data['type'] ?? json['category'] ?? data['category'] ?? json['type'],
    ),
    createdAt: _date(json['created_at']) ?? DateTime.now(),
    data: data,
    readAt: readAt,
    isRead: isRead,
  );
}
