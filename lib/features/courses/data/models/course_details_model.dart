import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/features/courses/domain/entities/course_details.dart';
import 'package:itaaleem/features/teachers/data/models/teacher_model.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

/// Maps `GET /courses/{id}` onto [CourseDetails] — the course plus its
/// sections ("المواد") and lectures ("الدروس").
///
/// Field names confirmed against the live API response.
class CourseDetailsModel extends CourseDetails {
  const CourseDetailsModel({
    required super.id,
    required super.title,
    required super.sections,
    super.imageUrl,
    super.description,
    super.progressPercent,
    super.exams,
    super.teachers,
  });

  factory CourseDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawSections =
        (json['sections'] ?? json['subjects'] ?? const []) as List;
    final rawExams = (json['exams'] as List?) ?? const [];
    final rawTeachers = (json['teachers'] as List?) ?? const [];
    return CourseDetailsModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name']) as String? ?? '',
      imageUrl: ApiEndpoints.mediaUrl(
        (json['thumbnail'] ?? json['image'] ?? json['cover']) as String?,
      ),
      description: json['description'] as String?,
      progressPercent: _asDouble(
        json['progress_percentage'] ?? json['progress'],
      ),
      sections: rawSections
          .map((e) => CourseSectionModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      exams: rawExams
          .map((e) => CourseExamModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      teachers: rawTeachers
          .map((e) => TeacherModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class CourseExamModel extends CourseExam {
  const CourseExamModel({
    required super.id,
    required super.title,
    super.questionsCount,
    super.durationMinutes,
    super.createdAt,
    super.attempted,
    super.score,
    super.passed,
  });

  factory CourseExamModel.fromJson(Map<String, dynamic> json) {
    return CourseExamModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name']) as String? ?? '',
      questionsCount: _asInt(
        json['questions_count'] ?? json['questions_count_total'],
      ),
      durationMinutes: _asInt(json['duration_minutes'] ?? json['duration']),
      createdAt: _asDate(json['created_at']),
      attempted: (json['attempted'] as bool?) ?? false,
      score: _asDouble(json['score']),
      passed: json['passed'] as bool?,
    );
  }

  static int? _asInt(Object? value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _asDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class CourseSectionModel extends CourseSection {
  const CourseSectionModel({
    required super.id,
    required super.title,
    required super.lectures,
    super.thumbnailUrl,
    super.teachers,
  });

  factory CourseSectionModel.fromJson(Map<String, dynamic> json) {
    final rawLectures =
        (json['lectures'] ?? json['lessons'] ?? const []) as List;
    // The `section_teacher` pivot, embedded directly on the section object —
    // the primary source for "مدرسو هذه المادة" (see [CourseSection.teachers]).
    final rawTeachers = (json['teachers'] as List?) ?? const [];
    final teachers = rawTeachers
        .whereType<Map>()
        .map((e) => TeacherModel.fromJson(e.cast<String, dynamic>()))
        .toList();
    if (kDebugMode) {
      debugPrint(
        '[CourseSectionModel] section ${json['id']} '
        '"${json['title'] ?? json['name']}": '
        '${teachers.length} nested teacher(s) in JSON '
        '(keys present: ${json.keys.join(', ')})',
      );
    }
    return CourseSectionModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name']) as String? ?? '',
      thumbnailUrl: ApiEndpoints.mediaUrl(
        (json['thumbnail'] ?? json['image'] ?? json['cover']) as String?,
      ),
      teachers: teachers,
      lectures: rawLectures
          .map((e) => CourseLectureModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CourseLectureModel extends CourseLecture {
  const CourseLectureModel({
    required super.id,
    required super.title,
    required super.type,
    super.durationLabel,
    super.isCompleted,
    super.isLocked,
    super.isFreePreview,
    super.hasVideo,
    super.hasPdf,
    super.thumbnailUrl,
    super.teacherId,
  });

  /// A lecture has no `type` field of its own — instead it carries separate
  /// `videos`/`pdfs`/`attachments` arrays (a lecture can technically have
  /// more than one of each). The icon/type shown is whichever is present,
  /// video taking priority.
  factory CourseLectureModel.fromJson(Map<String, dynamic> json) {
    final videos = (json['videos'] as List?) ?? const [];
    final pdfs = (json['pdfs'] as List?) ?? const [];

    final teacherId = _teacherIdOf(json);
    if (kDebugMode) {
      debugPrint(
        '[CourseLectureModel] lecture ${json['id']} "${json['title'] ?? json['name']}": '
        'teacherId=$teacherId, keys present: ${json.keys.join(', ')}',
      );
      if (teacherId == null) {
        debugPrint(
          '[CourseLectureModel] lecture ${json['id']} has no teacher_id/doctor_id '
          'anywhere in its JSON — raw lecture JSON: $json',
        );
      }
    }

    return CourseLectureModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name']) as String? ?? '',
      type: videos.isNotEmpty
          ? LectureType.video
          : (pdfs.isNotEmpty ? LectureType.pdf : LectureType.other),
      durationLabel: _durationLabelOf(json, videos),
      isCompleted: (json['is_completed'] ?? json['completed'] ?? false) as bool,
      isLocked: _isLockedOf(json),
      isFreePreview: (json['is_free_preview'] as bool?) ?? false,
      hasVideo: videos.isNotEmpty,
      hasPdf: pdfs.isNotEmpty,
      thumbnailUrl: _thumbnailOf(videos),
      teacherId: teacherId,
    );
  }

  /// `is_locked` when the API sends it; otherwise the student's own
  /// `is_accessible` decides (`false` = locked). With neither field the lecture
  /// stays unlocked — locking on a missing field would lock every lecture for
  /// subscribed students too; a genuinely locked one is caught by the 403 on
  /// `GET /lectures/{id}` instead (see [LecturePlayerScreen]).
  static bool _isLockedOf(Map<String, dynamic> json) {
    final locked = json['is_locked'];
    if (locked is bool) return locked;
    final accessible = json['is_accessible'];
    if (accessible is bool) return !accessible;
    return false;
  }

  /// Not confirmed present on `GET /courses/{id}` lectures yet — parsed
  /// defensively (a bare `teacher_id`/`doctor_id`, or a nested
  /// `teacher`/`doctor` object's `id`) so the teacher-lecture filter picks
  /// it up the moment the backend adds it, without a follow-up client
  /// change.
  static int? _teacherIdOf(Map<String, dynamic> json) {
    final direct = json['teacher_id'] ?? json['doctor_id'];
    if (direct is num) return direct.toInt();
    final teacher = json['teacher'] ?? json['doctor'];
    if (teacher is Map) {
      final id = teacher['id'];
      if (id is num) return id.toInt();
    }
    return null;
  }

  /// The first video's own thumbnail if the API sends one, else a YouTube
  /// `hqdefault` built from its video id — YouTube never returns a
  /// thumbnail field of its own here, only the id.
  static String? _thumbnailOf(List videos) {
    if (videos.isEmpty) return null;
    final video = videos.first;
    if (video is! Map) return null;
    final json = video.cast<String, dynamic>();
    final ownThumbnail = ApiEndpoints.mediaUrl(json['thumbnail'] as String?);
    if (ownThumbnail != null) return ownThumbnail;
    if (json['provider'] == 'youtube') {
      final videoId = json['provider_video_id'] as String?;
      if (videoId != null && videoId.isNotEmpty) {
        return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      }
    }
    return null;
  }

  static String? _durationLabelOf(Map<String, dynamic> json, List videos) {
    var seconds = json['duration_seconds'] ?? json['duration'];
    if (seconds is! num && videos.isNotEmpty) {
      final firstVideo = videos.first;
      if (firstVideo is Map) seconds = firstVideo['duration_seconds'];
    }
    if (seconds is! num || seconds <= 0) return null;
    final totalMinutes = (seconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) {
      return '$hoursس ${minutes.toString().padLeft(2, '0')}د';
    }
    return '$minutesد';
  }
}
