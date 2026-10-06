import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/features/teachers/domain/entities/teacher.dart';

/// Maps a single item of the `GET /public/teachers` `data` array onto
/// [Teacher]. Field names are hedged defensively (the exact backend shape
/// isn't pinned down in APP_SPEC.md yet) the same way [CourseModel] hedges
/// `title`/`name` and `thumbnail`/`image`/`cover`.
class TeacherModel extends Teacher {
  const TeacherModel({
    required super.id,
    required super.name,
    required super.specialization,
    super.photoUrl,
    super.bio,
    super.courseIds,
    super.courseTitle,
    super.sectionIds,
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    final courseIds = <int>[];
    String? courseTitle;

    final singleCourseId = json['course_id'];
    if (singleCourseId is num) courseIds.add(singleCourseId.toInt());
    final singleCourseTitle = json['course_title'] ?? json['course_name'];
    if (singleCourseTitle is String) courseTitle = singleCourseTitle;

    final coursesRaw = json['courses'] ?? json['course_ids'];
    if (coursesRaw is List) {
      for (final entry in coursesRaw) {
        if (entry is num) {
          courseIds.add(entry.toInt());
        } else if (entry is Map) {
          final id = entry['id'];
          if (id is num) courseIds.add(id.toInt());
          courseTitle ??= (entry['title'] ?? entry['name']) as String?;
        }
      }
    }

    final sectionIds = <int>[];
    final sectionsRaw = json['sections'] ?? json['section_ids'];
    if (sectionsRaw is List) {
      for (final entry in sectionsRaw) {
        if (entry is num) {
          sectionIds.add(entry.toInt());
        } else if (entry is Map) {
          final id = entry['id'];
          if (id is num) sectionIds.add(id.toInt());
        }
      }
    }

    return TeacherModel(
      id: _asInt(json['id']),
      name:
          (json['name'] ?? json['full_name'] ?? json['teacher_name'])
              as String? ??
          '',
      specialization:
          (json['specialization'] ?? json['subject'] ?? json['major'])
              as String? ??
          '',
      photoUrl: ApiEndpoints.mediaUrl(
        (json['photo_url'] ?? json['photo'] ?? json['avatar'] ?? json['image'])
            as String?,
      ),
      bio: (json['bio'] ?? json['about'] ?? json['description']) as String?,
      courseIds: courseIds,
      courseTitle: courseTitle,
      sectionIds: sectionIds,
    );
  }

  static int _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
