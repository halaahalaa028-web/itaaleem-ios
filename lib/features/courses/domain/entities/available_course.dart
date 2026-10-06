/// A student's relationship to a course in the catalog.
enum EnrollmentStatus {
  /// Not enrolled and no pending request.
  none,

  /// Enrollment requested via `POST /courses/{id}/request`, awaiting
  /// admin activation.
  pending,

  /// Enrolled and active.
  active,
}

/// One entry of the full course catalog from `GET /courses/available` —
/// every published course, whether or not the student is enrolled.
class AvailableCourse {
  const AvailableCourse({
    required this.id,
    required this.title,
    required this.subjectsCount,
    required this.lecturesCount,
    required this.enrollmentStatus,
    this.description,
    this.thumbnailUrl,
    this.price,
    this.category,
  });

  final int id;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final double? price;
  final String? category;
  final int subjectsCount;
  final int lecturesCount;
  final EnrollmentStatus enrollmentStatus;

  bool get isEnrolled => enrollmentStatus == EnrollmentStatus.active;
}
