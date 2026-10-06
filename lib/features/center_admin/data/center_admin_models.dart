import 'package:itaaleem/core/network/api_endpoints.dart';

/// One row from any `/center-admin/*` endpoint.
///
/// The exact shapes of these endpoints aren't documented, so instead of a
/// rigid model per resource this wraps the raw JSON and reads each field
/// defensively from the names the backend is most likely to use (the same
/// approach as the notifications parser). Screens ask for what they show —
/// [title], [image], [count], [nestedName] — and get `null` when absent.
class AdminRecord {
  const AdminRecord(this.json);

  final Map<String, dynamic> json;

  int get id => _int(json['id']) ?? 0;

  /// The display name of whatever this is.
  String get title =>
      text(['name', 'full_name', 'title', 'student_name', 'label']) ??
      (id > 0 ? '#$id' : '—');

  String? text(List<String> keys) {
    for (final key in keys) {
      final value = _textOf(json[key]);
      if (value != null) return value;
    }
    return null;
  }

  num? number(List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      final value = raw is num ? raw : num.tryParse('${raw ?? ''}');
      if (value != null) return value;
    }
    return null;
  }

  int? count(List<String> keys) => number(keys)?.toInt();

  bool? flag(List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.toLowerCase();
        if (s == 'true' || s == '1' || s == 'active') return true;
        if (s == 'false' || s == '0' || s == 'inactive') return false;
      }
    }
    return null;
  }

  DateTime? date(List<String> keys) {
    for (final key in keys) {
      final raw = json[key];
      if (raw == null) continue;
      final parsed = DateTime.tryParse('$raw');
      if (parsed != null) return parsed.toLocal();
    }
    return null;
  }

  /// A nested object (`subject`, `student`, `teacher`, …) as a record.
  AdminRecord? nested(String key) {
    final value = json[key];
    return value is Map ? AdminRecord(Map<String, dynamic>.from(value)) : null;
  }

  /// `subject.name`, else a flat `subject_name`.
  String? nestedName(String key) =>
      nested(key)?.text(['name', 'full_name', 'title']) ??
      text(['${key}_name', '${key}_title']);

  int? nestedId(String key) => nested(key)?.id ?? _int(json['${key}_id']);

  /// A nested list (`subscriptions`, `subjects`, …) as records.
  List<AdminRecord> list(String key) {
    final value = json[key];
    if (value is! List) return const [];
    return [
      for (final e in value)
        if (e is Map) AdminRecord(Map<String, dynamic>.from(e)),
    ];
  }

  String? get image => ApiEndpoints.mediaUrl(
    text([
      'photo_url',
      'avatar_url',
      'image_url',
      'icon_url',
      'logo_url',
      'thumbnail_url',
      'photo',
      'avatar',
      'image',
      'icon',
      'logo',
      'thumbnail',
    ]),
  );

  String? get phone => text(['phone', 'mobile', 'phone_number']);
  String? get email => text(['email']);

  /// Lower-cased `status` (`active` / `expired` / `suspended` / …), or one
  /// derived from an `is_active` flag.
  String? get status {
    final s = text(['status', 'state']);
    if (s != null) return s.toLowerCase();
    final active = flag(['is_active', 'active', 'enabled']);
    return active == null ? null : (active ? 'active' : 'inactive');
  }

  static String? _textOf(Object? raw) {
    if (raw == null || raw is Map || raw is List) {
      if (raw is Map) return _textOf(raw['ar'] ?? raw['name'] ?? raw['en']);
      return null;
    }
    final s = raw.toString().trim();
    return s.isEmpty ? null : s;
  }

  static int? _int(Object? raw) =>
      raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}');
}

/// One page of a paginated `/center-admin/*` list.
class AdminPageResult {
  const AdminPageResult({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<AdminRecord> items;
  final int page;
  final bool hasMore;
}

/// `GET /center-admin/dashboard`.
class CenterDashboardData {
  const CenterDashboardData({
    required this.stats,
    required this.recentSubscriptions,
    required this.recentStudents,
    this.centerName,
    this.centerLogo,
  });

  final AdminRecord stats;
  final List<AdminRecord> recentSubscriptions;
  final List<AdminRecord> recentStudents;
  final String? centerName;
  final String? centerLogo;
}

/// Pulls the list out of whichever envelope the API used: a bare list,
/// `{data: [...]}`, `{data: {items|data: [...]}}`, or `{items: [...]}`.
List<dynamic> extractAdminList(Object? body, [int depth = 0]) {
  if (body is List) return body;
  if (body is! Map || depth > 3) return const [];
  for (final key in ['items', 'data', 'results', 'records']) {
    final value = body[key];
    if (value is List) return value;
  }
  final data = body['data'];
  if (data is Map) return extractAdminList(data, depth + 1);
  return const [];
}

/// The object inside `{data: {...}}` (or the body itself).
Map<String, dynamic> extractAdminObject(Object? body) {
  if (body is Map) {
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return Map<String, dynamic>.from(body);
  }
  return const {};
}

/// `meta: {current_page, last_page}` at the root or under `data`.
({int page, bool hasMore}) extractAdminPaging(
  Object? body,
  int requestedPage,
  int itemCount,
  int perPage,
) {
  Map? meta;
  if (body is Map) {
    final data = body['data'];
    meta = body['meta'] is Map
        ? body['meta'] as Map
        : (data is Map && data['meta'] is Map
              ? data['meta'] as Map
              : (data is Map ? data : body));
  }
  int? i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
  final current = i(meta?['current_page']) ?? requestedPage;
  final last = i(meta?['last_page']);
  final hasMore = last != null
      ? current < last
      : (meta?['next_page_url'] != null || itemCount >= perPage);
  return (page: current, hasMore: hasMore && itemCount > 0);
}
