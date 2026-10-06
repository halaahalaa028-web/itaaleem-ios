/// Summary shape of a course as listed by `GET /courses` (the student's
/// enrolled/activated courses).
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.subjectsCount,
    this.imageUrl,
    this.progressPercent = 0,
  });

  final int id;
  final String title;
  final String? imageUrl;

  /// 0-100.
  final double progressPercent;
  final int subjectsCount;
}
