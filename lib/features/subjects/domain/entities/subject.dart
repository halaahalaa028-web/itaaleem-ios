/// One lesson of a [Subject] — `GET /subjects` embeds these on the detail
/// call, and `GET /lessons?subject_id=` returns the same shape standalone.
class SubjectLesson {
  const SubjectLesson({
    required this.id,
    required this.title,
    this.description,
    this.videoUrl,
    this.pdfUrl,
    this.thumbnailUrl,
    this.durationMinutes,
    this.isFree = false,
    this.isAccessible,
    this.hasVideoFlag,
    this.sortOrder = 0,
    this.isDownloadable = false,
    this.teacherId,
    this.teacherName,
    this.examsCount,
  });

  /// The lecture's own doctor, when the API sends `teacher_id`/`teacher`.
  final int? teacherId;
  final String? teacherName;

  /// `exams_count` (or the embedded `exams` list's length), when sent.
  final int? examsCount;

  final int id;
  final String title;
  final String? description;
  final String? videoUrl;
  final String? pdfUrl;
  final String? thumbnailUrl;
  final int? durationMinutes;

  /// The API's own lock signal for a lesson — there's no separate
  /// "unlocked by enrollment" concept exposed here, so this is treated as
  /// the lesson's lock state directly.
  final bool isFree;

  /// The API's per-student `is_accessible` — `true` means this student can
  /// already open it (e.g. subscribed); `null` when the API doesn't send it.
  final bool? isAccessible;

  /// The API's own `has_video` — for a paid lesson the student can't access
  /// yet it's `true` while `video_url` is withheld (`null`).
  final bool? hasVideoFlag;
  final int sortOrder;

  /// The API's `is_downloadable` — whether this lesson's PDF may be saved to
  /// the device. Absent means not downloadable.
  final bool isDownloadable;

  /// A video exists for this lesson (even if its URL is withheld).
  bool get hasVideo => hasVideoFlag ?? canPlayVideo;

  /// The video URL was actually sent, i.e. it can be played/downloaded now.
  bool get canPlayVideo => videoUrl != null && videoUrl!.isNotEmpty;
  bool get hasPdf => pdfUrl != null && pdfUrl!.isNotEmpty;
}

/// One exam of a [Subject], as embedded in `GET /subjects/{id}` — same
/// shape `GET /exams` returns per item (plus that endpoint's own `subject`
/// back-reference, dropped here since it's redundant in this context).
class SubjectExam {
  const SubjectExam({
    required this.id,
    required this.title,
    required this.questionsCount,
    this.durationMinutes,
    required this.passPercentage,
    this.isLocked = false,
  });

  final int id;
  final String title;
  final int questionsCount;
  final int? durationMinutes;
  final int passPercentage;
  final bool isLocked;
}

/// One file from `GET /attachments?subject_id=`.
class SubjectAttachment {
  const SubjectAttachment({
    required this.id,
    required this.name,
    required this.url,
    this.sizeLabel,
    this.type,
    this.lessonId,
    this.isDownloadable = false,
  });

  final int id;
  final String name;
  final String url;

  /// The lesson this file belongs to, when the API says so — `null` for a
  /// subject-wide file.
  final int? lessonId;

  /// The API's `is_downloadable` for this file; absent means not downloadable.
  final bool isDownloadable;

  bool get isPdf =>
      type?.toUpperCase() == 'PDF' ||
      url.toLowerCase().split('?').first.endsWith('.pdf');

  /// Already human-readable (e.g. `"2.5 MB"`) — formatted client-side from
  /// whichever byte-count field the API sends, when it sends one.
  final String? sizeLabel;

  /// File extension/type (e.g. `"pdf"`, `"docx"`), uppercased for display.
  final String? type;
}

/// One of a subject's doctors (`teachers[]` in `GET /subjects`).
class SubjectTeacher {
  const SubjectTeacher({this.id, required this.name, this.photoUrl});

  final int? id;
  final String name;
  final String? photoUrl;
}

/// A "مادة" the student's joined center/grade offers — `GET /subjects`
/// (list, no `lessons`/`exams`) and `GET /subjects/{id}` (detail, both
/// populated).
class Subject {
  const Subject({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.lessonsCount = 0,
    this.examsCount = 0,
    this.lessons = const [],
    this.exams = const [],
    this.teacherId,
    this.teacherName,
    this.teacherPhotoUrl,
    this.teachers = const [],
    this.progressPercent,
  });

  /// Every doctor teaching this subject — a subject shared by several
  /// doctors appears under each of them on "موادي".
  final List<SubjectTeacher> teachers;

  /// The subject's doctor, when `GET /subjects` includes it (`teacher` /
  /// `doctor` object, or flat `teacher_name`) — "موادي" groups by it.
  final int? teacherId;
  final String? teacherName;
  final String? teacherPhotoUrl;

  /// 0–100 completion, when the API sends it (`progress`,
  /// `progress_percentage`, `completion_percentage`).
  final double? progressPercent;

  final int id;
  final String name;
  final String? description;
  final String? iconUrl;
  final int lessonsCount;
  final int examsCount;
  final List<SubjectLesson> lessons;
  final List<SubjectExam> exams;
}
