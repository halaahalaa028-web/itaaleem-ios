import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/features/courses/domain/entities/course.dart';

/// Maps a single item of the `GET /courses` `data` array onto [Course].
///
/// Field names follow the confirmed `GET /courses/available` /
/// `GET /courses/{id}` conventions: `thumbnail` is a storage-relative path
/// (resolved via [ApiEndpoints.mediaUrl]), counts use `materials_count`, and
/// numeric-looking fields (`progress_percentage`) may arrive as strings.
class CourseModel extends Course {
  const CourseModel({
    required super.id,
    required super.title,
    required super.subjectsCount,
    super.imageUrl,
    super.progressPercent,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) {
    return CourseModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name']) as String? ?? '',
      imageUrl: ApiEndpoints.mediaUrl(
        (json['thumbnail'] ?? json['image'] ?? json['cover']) as String?,
      ),
      progressPercent: _asDouble(
        json['progress_percentage'] ?? json['progress'],
      ),
      subjectsCount: _asInt(
        json['materials_count'] ??
            json['subjects_count'] ??
            json['sections_count'],
      ),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
