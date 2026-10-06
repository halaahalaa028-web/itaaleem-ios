import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/features/courses/domain/entities/lecture_details.dart';
import 'package:flutter/foundation.dart';

/// Maps `GET /lectures/{id}` onto [LectureDetails]. Field names confirmed
/// against the live API response.
class LectureDetailsModel extends LectureDetails {
  const LectureDetailsModel({
    required super.id,
    required super.title,
    super.description,
    super.videos,
    super.pdfs,
    super.attachments,
    super.teacherId,
    super.isDownloadable,
  });

  factory LectureDetailsModel.fromJson(Map<String, dynamic> json) {
    final rawVideos = (json['videos'] as List?) ?? const [];
    final rawPdfs = (json['pdfs'] as List?) ?? const [];
    final rawAttachments = (json['attachments'] as List?) ?? const [];
    final teacherId = _teacherIdOf(json);
    if (kDebugMode) {
      debugPrint(
        '[LectureDetailsModel] lecture ${json['id']}: '
        '${rawPdfs.length} pdf(s) in raw response: $rawPdfs',
      );
    }
    final pdfs = rawPdfs
        .map((e) => LecturePdfModel.fromJson(e as Map<String, dynamic>))
        .toList();
    if (kDebugMode) {
      for (final pdf in pdfs) {
        debugPrint(
          '[LectureDetailsModel] parsed pdf id=${pdf.id} title="${pdf.title}" '
          'fileUrl=${pdf.fileUrl}',
        );
      }
    }
    return LectureDetailsModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name']) as String? ?? '',
      description: json['description'] as String?,
      videos: rawVideos
          .map((e) => LectureVideoModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      pdfs: pdfs,
      attachments: rawAttachments
          .map(
            (e) => LectureAttachmentModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      teacherId: teacherId,
      isDownloadable: (json['is_downloadable'] as bool?) ?? false,
    );
  }

  /// Same defensive shape as [CourseLectureModel._teacherIdOf] — a bare
  /// `teacher_id`/`doctor_id`, or a nested `teacher`/`doctor` object's `id`
  /// (confirmed present here: `GET /lectures/{id}` sends
  /// `"teacher": {"id": ..., "full_name": ..., "photo": ...}`).
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
}

class LectureAttachmentModel extends LectureAttachment {
  const LectureAttachmentModel({
    required super.id,
    required super.title,
    required super.fileUrl,
    super.isDownloadable,
  });

  factory LectureAttachmentModel.fromJson(Map<String, dynamic> json) {
    return LectureAttachmentModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name']) as String? ?? '',
      fileUrl: ApiEndpoints.mediaUrl(json['file_path'] as String?) ?? '',
      isDownloadable: (json['is_downloadable'] as bool?) ?? false,
    );
  }
}

class LecturePdfModel extends LecturePdf {
  const LecturePdfModel({
    required super.id,
    required super.title,
    required super.fileUrl,
    super.isDownloadable,
    super.lastPage,
    super.readPercentage,
  });

  factory LecturePdfModel.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    final progress = rawProgress is Map<String, dynamic> ? rawProgress : null;
    return LecturePdfModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: (json['title'] ?? json['name']) as String? ?? '',
      fileUrl: ApiEndpoints.mediaUrl(json['file_path'] as String?) ?? '',
      isDownloadable: (json['is_downloadable'] as bool?) ?? false,
      lastPage: (progress?['last_page'] as num?)?.toInt() ?? 1,
      readPercentage: _asDouble(progress?['read_percentage']),
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class LectureVideoModel extends LectureVideo {
  const LectureVideoModel({
    required super.id,
    required super.provider,
    super.providerVideoId,
    super.videoUrl,
    super.thumbnailUrl,
    super.durationSeconds,
    super.progress,
  });

  factory LectureVideoModel.fromJson(Map<String, dynamic> json) {
    final rawProgress = json['progress'];
    return LectureVideoModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      provider: _providerOf(json['provider'] as String?),
      providerVideoId: json['provider_video_id'] as String?,
      videoUrl: ApiEndpoints.mediaUrl(json['video_url'] as String?),
      thumbnailUrl: ApiEndpoints.mediaUrl(json['thumbnail'] as String?),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt(),
      progress: rawProgress is Map<String, dynamic>
          ? VideoProgressModel.fromJson(rawProgress)
          : null,
    );
  }

  static VideoProvider _providerOf(String? raw) {
    return switch (raw) {
      'youtube' => VideoProvider.youtube,
      'bunny' => VideoProvider.bunny,
      'vimeo' => VideoProvider.vimeo,
      'private_server' => VideoProvider.privateServer,
      _ => VideoProvider.unknown,
    };
  }
}

class VideoProgressModel extends VideoProgress {
  const VideoProgressModel({
    super.lastPositionSeconds,
    super.watchPercentage,
    super.totalWatchTimeSeconds,
    super.isCompleted,
  });

  factory VideoProgressModel.fromJson(Map<String, dynamic> json) {
    return VideoProgressModel(
      lastPositionSeconds:
          (json['last_position_seconds'] as num?)?.toInt() ?? 0,
      watchPercentage: _asDouble(json['watch_percentage']),
      totalWatchTimeSeconds:
          (json['total_watch_time_seconds'] as num?)?.toInt() ?? 0,
      isCompleted: (json['is_completed'] as bool?) ?? false,
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
