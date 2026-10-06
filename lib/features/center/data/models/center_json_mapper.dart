import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/features/center/domain/entities/center_model.dart';

/// Parses the JSON shapes returned by `GET /centers` (list items — no
/// `grades`) and `GET /centers/{id}` (detail — `grades` included) onto
/// [CenterModel]. Kept out of the domain entity itself, which stays
/// framework/API agnostic.
CenterModel centerModelFromJson(Map<String, dynamic> json) {
  final rawPhones = json['phone_numbers'];
  final rawSocial = json['social_links'];
  final rawGrades = json['grades'];

  return CenterModel(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    name: json['name'] as String? ?? '',
    code: json['code'] as String? ?? '',
    logo: ApiEndpoints.mediaUrl((json['logo_url'] ?? json['logo']) as String?),
    cover: ApiEndpoints.mediaUrl((json['cover_url'] ?? json['cover']) as String?),
    description: json['description'] as String?,
    address: json['address'] as String?,
    primaryColor: (json['primary_color'] as String?)?.trim().isNotEmpty == true
        ? json['primary_color'] as String
        : '#0B3D91',

    phoneNumbers: rawPhones is List
        ? rawPhones.map((e) => e.toString()).toList()
        : const [],

    email: _nonEmptyString(json['email'] ?? json['contact_email']),

    socialLinks: rawSocial is Map
        ? rawSocial.map(
          (key, value) => MapEntry(
        key.toString(),
        value?.toString(),
      ),
    )
        : const {},

    // API may return rating as String ("0.00") or num (0.0)
    rating: double.tryParse(
      json['rating']?.toString() ?? '',
    ) ??
        0.0,

    // API may return students_count as int or String
    studentsCount: int.tryParse(
      json['students_count']?.toString() ?? '',
    ) ??
        0,

    // The live backend's field name for this has been observed as both
    // `is_active` and `is_activated` — read whichever is present, defaulting
    // to active (not every response necessarily includes it, e.g. list rows
    // may omit it while detail rows include it).
    isActive:
        (json['is_active'] as bool?) ?? (json['is_activated'] as bool?) ?? true,

    grades: rawGrades is List
        ? rawGrades
        .whereType<Map<String, dynamic>>()
        .map(
          (e) => gradeModelFromJson(
        e,
      ),
    )
        .toList()
        : const [],
  );
}

String? _nonEmptyString(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

GradeModel gradeModelFromJson(Map<String, dynamic> json) {
  return GradeModel(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    name: json['name'] as String? ?? '',
    sortOrder: int.tryParse(
      json['sort_order']?.toString() ?? '',
    ) ??
        0,
  );
}