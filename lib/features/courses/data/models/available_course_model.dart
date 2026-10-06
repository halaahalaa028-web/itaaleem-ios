import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/features/courses/domain/entities/available_course.dart';

/// Maps a single item of `GET /courses/available`'s `data` array onto
/// [AvailableCourse]. Field names confirmed against the live API response:
/// `{id, title, description, thumbnail, price, category, materials_count,
/// lessons_count, is_enrolled, enrollment_status}` — `thumbnail` is a
/// storage-relative path (resolved via [ApiEndpoints.mediaUrl]) and `price`
/// comes back as a decimal string (e.g. `"2000.00"`).
class AvailableCourseModel extends AvailableCourse {
  const AvailableCourseModel({
    required super.id,
    required super.title,
    required super.subjectsCount,
    required super.lecturesCount,
    required super.enrollmentStatus,
    super.description,
    super.thumbnailUrl,
    super.price,
    super.category,
  });

  factory AvailableCourseModel.fromJson(Map<String, dynamic> json) {
    final isEnrolled = json['is_enrolled'] as bool? ?? false;
    return AvailableCourseModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name']) as String? ?? '',
      description: json['description'] as String?,
      thumbnailUrl: ApiEndpoints.mediaUrl(
        (json['thumbnail'] ?? json['image'] ?? json['cover']) as String?,
      ),
      price: _asNullableDouble(json['price']),
      category: _categoryOf(json['category']),
      subjectsCount: _asInt(
        json['materials_count'] ??
            json['subjects_count'] ??
            json['sections_count'],
      ),
      lecturesCount: _asInt(json['lessons_count'] ?? json['lectures_count']),
      enrollmentStatus: _statusOf(
        json['enrollment_status'] as String?,
        isEnrolled,
      ),
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _asNullableDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String? _categoryOf(Object? value) {
    if (value is String) return value;
    if (value is Map && value['name'] is String) return value['name'] as String;
    return null;
  }

  static EnrollmentStatus _statusOf(String? raw, bool isEnrolled) {
    switch (raw?.toLowerCase()) {
      case 'active':
        return EnrollmentStatus.active;
      case 'pending':
        return EnrollmentStatus.pending;
      default:
        return isEnrolled ? EnrollmentStatus.active : EnrollmentStatus.none;
    }
  }
}
