/// One subject subscription of the current student (`GET /my-subscriptions`,
/// or the `subscription` object of `GET /subjects/{id}/subscription-status`).
class SubjectSubscription {
  const SubjectSubscription({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    this.subjectIcon,
    required this.status,
    this.startsAt,
    this.expiresAt,
    this.teacherName,
    this.lecturesCount,
  });

  /// The subject's doctor/teacher, when the API includes it.
  final String? teacherName;

  /// How many lectures the subject has, when the API includes it.
  final int? lecturesCount;

  final int id;
  final int subjectId;
  final String subjectName;
  final String? subjectIcon;

  /// `active`, `expired` or `cancelled`.
  final String status;
  final DateTime? startsAt;

  /// `null` = lifetime.
  final DateTime? expiresAt;

  bool get isExpired =>
      status == 'expired' ||
      (expiresAt != null && DateTime.now().isAfter(expiresAt!));

  bool get isCancelled => status == 'cancelled';

  bool get isActive =>
      (status == 'active' || status == '1' || status == 'true') && !isExpired;

  factory SubjectSubscription.fromJson(Map<String, dynamic> json) {
    final subject = json['subject'];
    final subjectMap = subject is Map
        ? Map<String, dynamic>.from(subject)
        : null;
    final teacher =
        subjectMap?['teacher'] ?? subjectMap?['doctor'] ?? json['teacher'];
    final teacherName =
        (teacher is Map
                ? (teacher['name'] ?? teacher['full_name'])
                : (teacher ??
                      subjectMap?['teacher_name'] ??
                      subjectMap?['doctor_name'] ??
                      json['teacher_name'] ??
                      json['doctor_name']))
            ?.toString();
    // Some backends send a boolean instead of a status string.
    final rawStatus = json['status'] ?? json['state'];
    final activeFlag = _asBool(json['is_active'] ?? json['active']);
    final status = rawStatus != null
        ? rawStatus.toString().toLowerCase()
        : (activeFlag == false ? 'expired' : 'active');
    return SubjectSubscription(
      teacherName: teacherName == null || teacherName.trim().isEmpty
          ? null
          : teacherName,
      lecturesCount: _asInt(
        subjectMap?['lectures_count'] ??
            subjectMap?['lessons_count'] ??
            json['lectures_count'] ??
            json['lessons_count'],
      ),
      id: _asInt(json['id']) ?? 0,
      subjectId: _asInt(subjectMap?['id'] ?? json['subject_id']) ?? 0,
      subjectName:
          (subjectMap?['name'] ??
                  subjectMap?['title'] ??
                  json['subject_name'] ??
                  json['name'])
              ?.toString() ??
          '',
      subjectIcon: (subjectMap?['icon'] ?? subjectMap?['icon_url'])?.toString(),
      status: status,
      startsAt: _asDate(json['starts_at'] ?? json['start_date']),
      expiresAt: _asDate(
        json['expires_at'] ?? json['end_date'] ?? json['ends_at'],
      ),
    );
  }
}

/// `GET /subjects/{id}/subscription-status`.
class SubjectSubscriptionStatus {
  const SubjectSubscriptionStatus({
    required this.subscribed,
    required this.requiresSubscription,
    this.price,
    this.subscription,
  });

  /// Open by default: used until/unless the API says otherwise (endpoint
  /// missing, demo session, …), so nothing gets locked by mistake.
  const SubjectSubscriptionStatus.open()
    : subscribed = true,
      requiresSubscription = false,
      price = null,
      subscription = null;

  final bool subscribed;
  final bool requiresSubscription;

  /// Display price in EGP, when the center set one.
  final double? price;
  final SubjectSubscription? subscription;

  /// A subject that doesn't need a subscription is always open.
  bool get hasAccess =>
      !requiresSubscription ||
      (subscribed && (subscription == null || subscription!.isActive));

  factory SubjectSubscriptionStatus.fromJson(Map<String, dynamic> json) {
    // Accept both a bare body and Laravel's `{data: {...}}` envelope.
    final data = json['data'];
    final body = data is Map<String, dynamic> ? data : json;
    final sub = body['subscription'];
    return SubjectSubscriptionStatus(
      subscribed: _asBool(body['subscribed']) ?? false,
      requiresSubscription: _asBool(body['requires_subscription']) ?? false,
      price: _asDouble(body['price']),
      subscription: sub is Map<String, dynamic>
          ? SubjectSubscription.fromJson(sub)
          : null,
    );
  }
}

int? _asInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

double? _asDouble(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

bool? _asBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return null;
}

DateTime? _asDate(Object? v) => v == null ? null : DateTime.tryParse('$v');
