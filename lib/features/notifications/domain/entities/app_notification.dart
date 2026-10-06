/// Category of a notification — drives its icon, its tab in
/// [NotificationsScreen] and where tapping it navigates. `other` covers any
/// server `type` value the app doesn't recognize.
enum AppNotificationType { lecture, exam, assignment, announcement, other }

/// One notification — either an item of `GET /notifications`, or (when
/// [isLocal]) a push recorded on-device by `NotificationHistoryService`
/// that the server list doesn't contain.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    required this.type,
    required this.createdAt,
    this.data = const {},
    this.readAt,
    this.isRead = false,
    this.isLocal = false,
  });

  /// String, not int: Laravel database notifications use UUIDs.
  final String id;
  final String title;
  final String? body;
  final AppNotificationType type;
  final DateTime createdAt;

  /// The raw `data` payload — holds the target ids used for navigation
  /// (`lecture_id`, `exam_id`, `assignment_id`, or a generic `id`).
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final bool isRead;
  final bool isLocal;

  /// The id of the lecture/exam/assignment this notification points at.
  int? get targetId {
    final key = switch (type) {
      AppNotificationType.lecture => 'lecture_id',
      AppNotificationType.exam => 'exam_id',
      AppNotificationType.assignment => 'assignment_id',
      _ => null,
    };
    final raw =
        (key != null ? data[key] : null) ??
        data['target_id'] ??
        data['model_id'] ??
        data['id'];
    return raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  }

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    title: title,
    body: body,
    type: type,
    createdAt: createdAt,
    data: data,
    readAt: readAt,
    isRead: isRead ?? this.isRead,
    isLocal: isLocal,
  );
}
