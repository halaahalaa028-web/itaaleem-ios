import 'package:itaaleem/core/network/api_endpoints.dart';

// Wire models for the in-app admin dashboard (`/admin/*`, see
// `docs/api/admin_routes.md`). The endpoints are new, so every `fromJson`
// is written defensively: ids/counts may arrive as strings, relations
// nested (`student: {id, name}`) or flat (`student_id`, `student_name`).

int _int(Object? v) => int.tryParse(v?.toString() ?? '') ?? 0;

int? _intOrNull(Object? v) => int.tryParse(v?.toString() ?? '');

String _str(Object? v) => v == null ? '' : v.toString();

String? _strOrNull(Object? v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}

bool _bool(Object? v, {bool fallback = false}) {
  if (v == null) return fallback;
  return v == true || v == 1 || v == '1' || v == 'true';
}

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

Map<String, dynamic> _map(Object? v) =>
    v is Map<String, dynamic> ? v : const {};

List<Map<String, dynamic>> _list(Object? v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : const [];

/// `yyyy-MM-dd`, the format every admin endpoint takes dates in.
String apiDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// `yyyy/MM/dd` for display.
String displayDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// The dashboard header counters.
class AdminStats {
  const AdminStats({
    required this.studentsCount,
    required this.subjectsCount,
    required this.activeSubscriptions,
    required this.pendingRequests,
    this.centerName,
    this.available = true,
  });

  /// `GET /admin/dashboard-stats` isn't reachable — the cards show "—".
  const AdminStats.unavailable()
    : studentsCount = 0,
      subjectsCount = 0,
      activeSubscriptions = 0,
      pendingRequests = 0,
      centerName = null,
      available = false;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    final body = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    return AdminStats(
      studentsCount: _int(body['students_count']),
      subjectsCount: _int(body['subjects_count']),
      activeSubscriptions: _int(body['active_subscriptions']),
      pendingRequests: _int(
        body['pending_requests'] ?? body['pending_subscription_requests'],
      ),
      centerName: _strOrNull(
        body['center_name'] ?? _map(body['center'])['name'],
      ),
    );
  }

  final int studentsCount;
  final int subjectsCount;
  final int activeSubscriptions;
  final int pendingRequests;
  final String? centerName;
  final bool available;
}

/// One page of a paginated list. Accepts Laravel's paginator shape
/// (`{data, meta: {current_page, last_page}}`, or the same keys at the
/// root) and the app API's `{data: {items, meta}}` envelope.
class AdminPage<T> {
  const AdminPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  factory AdminPage.fromJson(
    Object? json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    if (json is List) {
      return AdminPage(
        items: _list(json).map(fromJson).toList(),
        currentPage: 1,
        lastPage: 1,
      );
    }
    var body = _map(json);
    if (body['data'] is Map<String, dynamic>) {
      body = body['data'] as Map<String, dynamic>;
    }
    final raw = body['items'] ?? body['data'];
    final meta = body['meta'] is Map<String, dynamic>
        ? body['meta'] as Map<String, dynamic>
        : body;
    final current = _intOrNull(meta['current_page']) ?? 1;
    return AdminPage(
      items: _list(raw).map(fromJson).toList(),
      currentPage: current,
      lastPage: _intOrNull(meta['last_page']) ?? current,
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

class AdminStudent {
  const AdminStudent({
    required this.id,
    required this.name,
    required this.mobile,
    this.subjectsCount = 0,
    this.lastLoginAt,
    this.avatarUrl,
    this.isActive = true,
  });

  factory AdminStudent.fromJson(Map<String, dynamic> json) => AdminStudent(
    id: _int(json['id']),
    name: _str(json['name'] ?? json['full_name']),
    mobile: _str(json['mobile'] ?? json['phone']),
    subjectsCount: _int(
      json['subjects_count'] ?? json['active_subscriptions_count'],
    ),
    lastLoginAt: _date(json['last_login_at'] ?? json['last_seen_at']),
    avatarUrl: ApiEndpoints.mediaUrl(_strOrNull(json['avatar'])),
    isActive: _bool(json['is_active'], fallback: true),
  );

  final int id;
  final String name;
  final String mobile;
  final int subjectsCount;
  final DateTime? lastLoginAt;
  final String? avatarUrl;
  final bool isActive;
}

class AdminDevice {
  const AdminDevice({
    required this.id,
    required this.name,
    this.platform,
    this.lastUsedAt,
  });

  factory AdminDevice.fromJson(Map<String, dynamic> json) => AdminDevice(
    id: _int(json['id']),
    name: _str(json['device_name'] ?? json['name'] ?? json['model']),
    platform: _strOrNull(json['platform'] ?? json['os']),
    lastUsedAt: _date(json['last_used_at'] ?? json['updated_at']),
  );

  final int id;
  final String name;
  final String? platform;
  final DateTime? lastUsedAt;
}

class AdminExamResult {
  const AdminExamResult({
    required this.title,
    required this.score,
    required this.total,
    this.passed,
    this.submittedAt,
  });

  factory AdminExamResult.fromJson(Map<String, dynamic> json) =>
      AdminExamResult(
        title: _str(json['exam_title'] ?? _map(json['exam'])['title']),
        score: num.tryParse(_str(json['score'])) ?? 0,
        total: num.tryParse(_str(json['total_marks'] ?? json['total'])) ?? 0,
        passed: json['passed'] == null ? null : _bool(json['passed']),
        submittedAt: _date(json['submitted_at'] ?? json['created_at']),
      );

  final String title;
  final num score;
  final num total;
  final bool? passed;
  final DateTime? submittedAt;
}

class AdminStudentDetails {
  const AdminStudentDetails({
    required this.student,
    required this.subscriptions,
    required this.devices,
    required this.examResults,
  });

  factory AdminStudentDetails.fromJson(Map<String, dynamic> json) {
    final body = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final student = body['student'] is Map<String, dynamic>
        ? body['student'] as Map<String, dynamic>
        : body;
    return AdminStudentDetails(
      student: AdminStudent.fromJson(student),
      subscriptions: _list(body['subscriptions'])
          .map(
            (s) => AdminSubscription.fromJson({
              'student': {
                'id': student['id'],
                'name': student['name'],
                'mobile': student['mobile'],
              },
              ...s,
            }),
          )
          .toList(),
      devices: _list(body['devices']).map(AdminDevice.fromJson).toList(),
      examResults: _list(
        body['exam_results'] ?? body['exam_attempts'],
      ).map(AdminExamResult.fromJson).toList(),
    );
  }

  final AdminStudent student;
  final List<AdminSubscription> subscriptions;
  final List<AdminDevice> devices;
  final List<AdminExamResult> examResults;
}

class AdminSubject {
  const AdminSubject({
    required this.id,
    required this.name,
    this.studentsCount,
    this.lessonsCount,
    this.isActive = true,
    this.iconUrl,
  });

  factory AdminSubject.fromJson(Map<String, dynamic> json) => AdminSubject(
    id: _int(json['id']),
    name: _str(json['name'] ?? json['title']),
    studentsCount: _intOrNull(
      json['students_count'] ?? json['subscriptions_count'],
    ),
    lessonsCount: _intOrNull(json['lessons_count']),
    isActive: _bool(json['is_active'], fallback: true),
    iconUrl: ApiEndpoints.mediaUrl(_strOrNull(json['icon'] ?? json['image'])),
  );

  final int id;
  final String name;
  final int? studentsCount;
  final int? lessonsCount;
  final bool isActive;
  final String? iconUrl;
}

/// One weekly slot. [dayOfWeek] follows Carbon/PHP: 0 = Sunday … 6 =
/// Saturday. [startTime]/[endTime] are `HH:mm`.
class AdminSchedule {
  const AdminSchedule({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.teacherName,
    this.location,
  });

  factory AdminSchedule.fromJson(Map<String, dynamic> json) {
    final subject = _map(json['subject']);
    final teacher = _map(json['teacher']);
    return AdminSchedule(
      id: _int(json['id']),
      subjectId: _int(json['subject_id'] ?? subject['id']),
      subjectName: _str(json['subject_name'] ?? subject['name']),
      teacherName: _strOrNull(json['teacher_name'] ?? teacher['name']),
      dayOfWeek: _parseDay(json['day_of_week'] ?? json['day']),
      startTime: _hhmm(json['start_time']),
      endTime: _hhmm(json['end_time']),
      location: _strOrNull(json['location'] ?? json['room']),
    );
  }

  static const _dayNames = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];

  static int _parseDay(Object? v) {
    final n = _intOrNull(v);
    if (n != null) return n % 7;
    final i = _dayNames.indexOf(_str(v).toLowerCase());
    return i < 0 ? 0 : i;
  }

  /// `"14:30:00"` → `"14:30"`.
  static String _hhmm(Object? v) {
    final s = _str(v);
    return s.length >= 5 ? s.substring(0, 5) : s;
  }

  final int id;
  final int subjectId;
  final String subjectName;
  final String? teacherName;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String? location;

  Map<String, dynamic> toJson() => {
    'subject_id': subjectId,
    'teacher_name': teacherName,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
    'location': location,
  };
}

class AdminSubscription {
  const AdminSubscription({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.subjectId,
    required this.subjectName,
    required this.status,
    this.studentMobile,
    this.startsAt,
    this.expiresAt,
  });

  factory AdminSubscription.fromJson(Map<String, dynamic> json) {
    final student = _map(json['student'] ?? json['user']);
    final subject = _map(json['subject']);
    return AdminSubscription(
      id: _int(json['id']),
      studentId: _int(json['student_id'] ?? json['user_id'] ?? student['id']),
      studentName: _str(json['student_name'] ?? student['name']),
      studentMobile: _strOrNull(json['student_mobile'] ?? student['mobile']),
      subjectId: _int(json['subject_id'] ?? subject['id']),
      subjectName: _str(json['subject_name'] ?? subject['name']),
      status: _str(json['status']).toLowerCase(),
      startsAt: _date(json['starts_at']),
      expiresAt: _date(json['expires_at']),
    );
  }

  final int id;
  final int studentId;
  final String studentName;
  final String? studentMobile;
  final int subjectId;
  final String subjectName;
  final String status;
  final DateTime? startsAt;
  final DateTime? expiresAt;

  bool get isCancelled => status == 'cancelled' || status == 'canceled';

  bool get isPending => status == 'pending';

  bool get isExpired =>
      status == 'expired' ||
      (expiresAt != null && expiresAt!.isBefore(DateTime.now()));

  bool get isActive => status == 'active' && !isExpired;
}

class AdminAnnouncement {
  const AdminAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.isActive,
    this.imageUrl,
    this.createdAt,
  });

  factory AdminAnnouncement.fromJson(Map<String, dynamic> json) =>
      AdminAnnouncement(
        id: _int(json['id']),
        title: _str(json['title']),
        body: _str(json['body'] ?? json['content'] ?? json['message']),
        isActive: _bool(json['is_active'], fallback: true),
        imageUrl: ApiEndpoints.mediaUrl(_strOrNull(json['image'])),
        createdAt: _date(json['created_at']),
      );

  final int id;
  final String title;
  final String body;
  final bool isActive;
  final String? imageUrl;
  final DateTime? createdAt;
}
