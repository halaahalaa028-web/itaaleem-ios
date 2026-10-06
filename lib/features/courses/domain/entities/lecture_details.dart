/// Full lecture shape from `GET /lectures/{id}` — only ever fetched for an
/// unlocked lecture; the API rejects locked ones with a 403 and returns none
/// of this.
class LectureDetails {
  const LectureDetails({
    required this.id,
    required this.title,
    this.description,
    this.videos = const [],
    this.pdfs = const [],
    this.attachments = const [],
    this.teacherId,
    this.isDownloadable = false,
  });

  final int id;
  final String title;
  final String? description;
  final List<LectureVideo> videos;
  final List<LecturePdf> pdfs;

  /// The lecture's own teacher, from the nested `teacher` object
  /// `GET /lectures/{id}` carries (unlike `GET /courses/{id}`'s lecture
  /// list, which has never been observed to include any teacher linkage at
  /// all — see [SectionLessonsScreen]'s per-lecture teacher resolution).
  /// Null when the API sends none.
  final int? teacherId;

  /// Whether this lecture's video may be downloaded for offline playback —
  /// gates the "تحميل" button in [LecturePlayerScreen], same
  /// `is_downloadable` convention as [LecturePdf]/[LectureAttachment].
  final bool isDownloadable;

  /// Non-PDF files attached to the lecture (docs, images, ...) — same shape
  /// as [LecturePdf] but opened externally instead of in the in-app viewer,
  /// since there's no reading-progress endpoint for them.
  final List<LectureAttachment> attachments;

  /// The lecture's primary video, if it has one (a lecture can technically
  /// carry more than one, but the player only ever shows the first).
  LectureVideo? get primaryVideo => videos.isEmpty ? null : videos.first;

  /// The lecture's primary PDF attachment, if it has one (same
  /// first-of-possibly-many convention as [primaryVideo]).
  LecturePdf? get primaryPdf => pdfs.isEmpty ? null : pdfs.first;
}

class LecturePdf {
  const LecturePdf({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.isDownloadable = false,
    this.lastPage = 1,
    this.readPercentage = 0,
  });

  final int id;
  final String title;
  final String fileUrl;
  final bool isDownloadable;

  /// Where the student left off reading, if the API reports it — mirrors
  /// [VideoProgress.lastPositionSeconds] for resuming playback.
  final int lastPage;
  final double readPercentage;
}

class LectureAttachment {
  const LectureAttachment({
    required this.id,
    required this.title,
    required this.fileUrl,
    this.isDownloadable = false,
  });

  final int id;
  final String title;
  final String fileUrl;
  final bool isDownloadable;
}

/// Which backend the video is hosted on — drives which player widget the
/// screen picks; never hardcode a provider check outside of that dispatch.
enum VideoProvider { youtube, bunny, vimeo, privateServer, unknown }

class LectureVideo {
  const LectureVideo({
    required this.id,
    required this.provider,
    this.providerVideoId,
    this.videoUrl,
    this.thumbnailUrl,
    this.durationSeconds,
    this.progress,
  });

  final int id;
  final VideoProvider provider;
  final String? providerVideoId;
  final String? videoUrl;
  final String? thumbnailUrl;
  final int? durationSeconds;
  final VideoProgress? progress;
}

/// Mirrors the `progress` object embedded in a lecture's video, and the
/// response body of `POST /videos/{id}/progress`.
class VideoProgress {
  const VideoProgress({
    this.lastPositionSeconds = 0,
    this.watchPercentage = 0,
    this.totalWatchTimeSeconds = 0,
    this.isCompleted = false,
  });

  final int lastPositionSeconds;
  final double watchPercentage;
  final int totalWatchTimeSeconds;
  final bool isCompleted;
}

/// One alternate rendition offered by `GET /lectures/{id}/playback`, e.g.
/// `{"label": "720p", "url": "..."}` — same idea as
/// [AdvancedDirectPlayer]'s own track-based quality picker, but resolved
/// server-side into separate signed URLs instead of muxed tracks in one
/// stream.
class PlaybackQuality {
  const PlaybackQuality({required this.label, required this.url});

  final String label;
  final String url;
}

/// `GET /lectures/{id}/playback` — a signed, time-limited streaming URL for
/// the lecture's primary video, meant to replace [LectureVideo.videoUrl] as
/// the actual source handed to the player whenever this call succeeds (the
/// plain `video_url` is kept only as a fallback — see
/// `PrivateServerPlaybackResolver`).
class LecturePlaybackInfo {
  const LecturePlaybackInfo({
    required this.url,
    this.sourceType,
    this.qualities = const [],
    this.headers = const {},
    this.expiresAt,
  });

  final String url;
  final String? sourceType;
  final List<PlaybackQuality> qualities;

  /// Any headers the CDN requires on top of the signed URL itself (e.g. a
  /// `Referer` or API key) — passed straight through to media_kit's
  /// `Media(..., httpHeaders: ...)`.
  final Map<String, String> headers;
  final DateTime? expiresAt;
}

/// `GET`/`POST /lectures/{id}/progress` — lecture-level playback progress,
/// alongside (not a replacement for) the per-video [VideoProgress] embedded
/// in `GET /lectures/{id}`.
class LectureProgress {
  const LectureProgress({
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    this.progressPercentage = 0,
    this.isCompleted = false,
  });

  final int positionSeconds;
  final int durationSeconds;
  final double progressPercentage;
  final bool isCompleted;
}
