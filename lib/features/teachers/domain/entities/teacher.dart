/// A teacher as listed by `GET /public/teachers`.
class Teacher {
  const Teacher({
    required this.id,
    required this.name,
    required this.specialization,
    this.photoUrl,
    this.bio,
    this.courseIds = const [],
    this.courseTitle,
    this.sectionIds = const [],
  });

  final int id;
  final String name;
  final String specialization;
  final String? photoUrl;
  final String? bio;

  /// Ids of the course(s) this teacher is associated with, used to filter
  /// the home tab's list down to teachers behind a course the student is
  /// actually enrolled in.
  final List<int> courseIds;
  final String? courseTitle;

  /// Ids of the course section(s) ("مواد") this teacher covers, used to
  /// filter down to "مدرسو هذه المادة" on a single subject's lecture list.
  final List<int> sectionIds;

  /// What to show as the "subject" line under the teacher's name — their
  /// own specialization if the API sent one, else the course they're tied
  /// to, so the UI never shows a blank line.
  String get displaySpecialization =>
      specialization.isNotEmpty ? specialization : (courseTitle ?? '');
}
