import 'package:itaaleem/features/courses/domain/entities/course_details.dart';
import 'package:itaaleem/features/courses/presentation/providers/courses_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One "مادة" card on the home tab: a course section, tagged with which
/// enrolled course it belongs to.
class HomeSubject {
  const HomeSubject({
    required this.courseId,
    required this.courseTitle,
    required this.section,
    required this.courseExams,
    this.courseImageUrl,
  });

  final int courseId;
  final String courseTitle;
  final String? courseImageUrl;
  final CourseSection section;

  /// The parent course's exams, forwarded down to every lecture reached
  /// through this subject.
  final List<CourseExam> courseExams;

  /// The section's own thumbnail if the backend ever sends one, otherwise
  /// the parent course's cover image — the card falls back to a gradient
  /// icon only once both are absent.
  String? get thumbnailUrl => section.thumbnailUrl ?? courseImageUrl;

  int get lecturesCount => section.lectures.length;

  /// 0-100, derived from each lecture's own `is_completed` flag — the API
  /// has no per-section progress number of its own.
  double get progressPercent {
    if (section.lectures.isEmpty) return 0;
    final completed = section.lectures.where((l) => l.isCompleted).length;
    return completed / section.lectures.length * 100;
  }
}

/// Flattens every enrolled course's sections ("مواد") into one list for the
/// home tab: `GET /courses` for the enrolled course ids, then `GET
/// /courses/{id}` (in parallel) for each one's sections/exams.
final homeSubjectsProvider = FutureProvider<List<HomeSubject>>((ref) async {
  final courses = await ref.watch(coursesProvider.future);
  final detailsList = await Future.wait(
    courses.map(
      (course) => ref.watch(courseDetailsProvider(course.id).future),
    ),
  );

  final subjects = <HomeSubject>[];
  for (final details in detailsList) {
    for (final section in details.sections) {
      subjects.add(
        HomeSubject(
          courseId: details.id,
          courseTitle: details.title,
          courseImageUrl: details.imageUrl,
          section: section,
          courseExams: details.exams,
        ),
      );
    }
  }
  return subjects;
});
