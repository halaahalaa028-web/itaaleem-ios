import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';
import 'package:flutter/foundation.dart';

Subject subjectFromJson(Map<String, dynamic> json) {
  final rawLessons = json['lessons'] ?? json['lectures'];
  final rawExams = json['exams'];
  final teachers = json['teachers'];
  final teacherRaw =
      json['teacher'] ??
      json['doctor'] ??
      json['instructor'] ??
      (teachers is List && teachers.isNotEmpty ? teachers.first : null);
  final teacher = teacherRaw is Map ? teacherRaw : null;
  final teacherName =
      (teacher?['name'] ??
              teacher?['full_name'] ??
              (teacherRaw is String ? teacherRaw : null) ??
              json['teacher_name'] ??
              json['doctor_name'])
          ?.toString()
          .trim();
  final progressRaw =
      json['progress'] ??
      json['progress_percentage'] ??
      json['completion_percentage'];
  final progress = progressRaw is Map
      ? double.tryParse(
          '${progressRaw['percentage'] ?? progressRaw['percent']}',
        )
      : double.tryParse('${progressRaw ?? ''}');
  return Subject(
    teachers: [
      if (teachers is List)
        for (final t in teachers)
          if (t is Map &&
              '${t['name'] ?? t['full_name'] ?? ''}'.trim().isNotEmpty)
            SubjectTeacher(
              id: int.tryParse('${t['id'] ?? ''}'),
              name: '${t['name'] ?? t['full_name']}'.trim(),
              photoUrl: ApiEndpoints.mediaUrl(
                (t['photo_url'] ??
                        t['photo'] ??
                        t['avatar_url'] ??
                        t['avatar'] ??
                        t['image'])
                    ?.toString(),
              ),
            ),
    ],
    teacherId: int.tryParse(
      '${teacher?['id'] ?? json['teacher_id'] ?? json['doctor_id'] ?? ''}',
    ),
    teacherName: teacherName == null || teacherName.isEmpty
        ? null
        : teacherName,
    teacherPhotoUrl: ApiEndpoints.mediaUrl(
      (teacher?['photo_url'] ??
              teacher?['photo'] ??
              teacher?['avatar_url'] ??
              teacher?['avatar'] ??
              teacher?['image'])
          ?.toString(),
    ),
    // Some APIs send 0–1, most 0–100.
    progressPercent: progress == null
        ? null
        : (progress <= 1 && progress > 0 ? progress * 100 : progress)
              .clamp(0, 100)
              .toDouble(),
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    name: json['name'] as String? ?? '',
    description: json['description'] as String?,
    iconUrl: ApiEndpoints.mediaUrl(
      (json['icon_url'] ?? json['icon'] ?? json['image']) as String?,
    ),
    lessonsCount: int.tryParse(json['lessons_count']?.toString() ?? '') ?? 0,
    examsCount: int.tryParse(json['exams_count']?.toString() ?? '') ?? 0,
    lessons: rawLessons is List
        ? rawLessons
              .map((e) => subjectLessonFromJson(e as Map<String, dynamic>))
              .toList()
        : const [],
    exams: rawExams is List
        ? rawExams
              .map((e) => subjectExamFromJson(e as Map<String, dynamic>))
              .toList()
        : const [],
  );
}

SubjectLesson subjectLessonFromJson(Map<String, dynamic> json) {
  final teacherRaw = json['teacher'] ?? json['doctor'];
  final teacher = teacherRaw is Map ? teacherRaw : null;
  final teacherName =
      (teacher?['name'] ??
              (teacherRaw is String ? teacherRaw : null) ??
              json['teacher_name'])
          ?.toString()
          .trim();
  final exams = json['exams'];
  final lesson = SubjectLesson(
    teacherId: int.tryParse(
      '${teacher?['id'] ?? json['teacher_id'] ?? json['doctor_id'] ?? ''}',
    ),
    teacherName: teacherName == null || teacherName.isEmpty
        ? null
        : teacherName,
    examsCount:
        int.tryParse('${json['exams_count'] ?? ''}') ??
        (exams is List ? exams.length : null),
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    title: json['title'] as String? ?? '',
    description: json['description'] as String?,
    videoUrl: _videoUrlOf(json),
    pdfUrl: _pdfUrlOf(json),
    thumbnailUrl: ApiEndpoints.mediaUrl(
      (json['thumbnail_url'] ?? json['thumbnail']) as String?,
    ),
    durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? ''),
    isFree: _flag(json['is_free']) ?? false,
    isAccessible: _flag(json['is_accessible'] ?? json['has_access']),
    hasVideoFlag: _flag(json['has_video']),
    sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    isDownloadable: _flag(json['is_downloadable']) ?? false,
  );
  if (kDebugMode) {
    debugPrint('>>> lesson data: $json');
    debugPrint(
      '>>> has_video: ${lesson.hasVideo}, video_url: ${lesson.videoUrl}',
    );
  }
  return lesson;
}

/// The lesson's video, whichever shape the API actually uses for it — a
/// bare `video_url`/`video`/`media_url` string, or (mirroring
/// `LectureVideoModel`'s confirmed-live `GET /lectures/{id}` shape) a
/// `videos` array whose first item carries its own `video_url`/`url`.
/// Wrapped through [ApiEndpoints.mediaUrl] either way, since every other
/// storage-relative field in this app (avatars, logos, thumbnails, PDFs on
/// other models) needs that same resolution and this one plausibly does
/// too.
String? _videoUrlOf(Map<String, dynamic> json) {
  final direct =
      (json['video_url'] ?? json['video'] ?? json['media_url']) as String?;
  if (direct != null && direct.isNotEmpty) return ApiEndpoints.mediaUrl(direct);

  final videos = json['videos'];
  if (videos is List && videos.isNotEmpty) {
    final first = videos.first;
    if (first is Map) {
      final url =
          (first['video_url'] ?? first['url'] ?? first['path']) as String?;
      if (url != null && url.isNotEmpty) return ApiEndpoints.mediaUrl(url);
    }
  }
  return null;
}

/// Same idea as [_videoUrlOf], for the lesson's PDF.
String? _pdfUrlOf(Map<String, dynamic> json) {
  final direct =
      (json['pdf_url'] ??
              json['pdf'] ??
              json['file_url'] ??
              json['attachment_url'])
          as String?;
  if (direct != null && direct.isNotEmpty) return ApiEndpoints.mediaUrl(direct);

  final pdfs = json['pdfs'];
  if (pdfs is List && pdfs.isNotEmpty) {
    final first = pdfs.first;
    if (first is Map) {
      final url =
          (first['file_url'] ?? first['url'] ?? first['path']) as String?;
      if (url != null && url.isNotEmpty) return ApiEndpoints.mediaUrl(url);
    }
  }
  return null;
}

SubjectExam subjectExamFromJson(Map<String, dynamic> json) {
  return SubjectExam(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    title: json['title'] as String? ?? '',
    questionsCount: json['questions_count'] as int? ?? 0,
    durationMinutes: json['duration_minutes'] as int?,
    passPercentage: json['pass_percentage'] as int? ?? 60,
    isLocked: json['is_locked'] as bool? ?? false,
  );
}

SubjectAttachment subjectAttachmentFromJson(Map<String, dynamic> json) {
  final url =
      (json['url'] ?? json['file_url'] ?? json['path'] ?? json['file'])
          as String?;
  final type =
      (json['type'] ?? json['extension'] ?? json['mime_type']) as String?;
  return SubjectAttachment(
    id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
    name:
        (json['name'] ?? json['title'] ?? json['filename']) as String? ?? 'ملف',
    url: ApiEndpoints.mediaUrl(url) ?? url ?? '',
    sizeLabel: _sizeLabelOf(
      json['size'] ?? json['size_label'] ?? json['file_size'],
    ),
    type: type?.split('/').last.toUpperCase(),
    isDownloadable: _flag(json['is_downloadable']) ?? false,
    lessonId: int.tryParse(
      (json['lesson_id'] ??
                  json['lecture_id'] ??
                  (json['lesson'] is Map ? json['lesson']['id'] : null))
              ?.toString() ??
          '',
    ),
  );
}

String? _sizeLabelOf(Object? value) {
  if (value is String) return value;
  if (value is num) {
    final bytes = value.toDouble();
    if (bytes < 1024) return '${bytes.round()} B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return null;
}

/// `true`/`false`, `1`/`0` or `"1"`/`"true"` — `null` when absent.
bool? _flag(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().toLowerCase();
  return text == '1' || text == 'true';
}
