import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:itaaleem/features/courses/domain/entities/course_details.dart';
import 'package:itaaleem/features/courses/presentation/providers/courses_providers.dart';
import 'package:itaaleem/features/courses/presentation/widgets/course_details_shimmer.dart';
import 'package:itaaleem/features/courses/presentation/widgets/gradient_back_bar.dart';
import 'package:itaaleem/features/courses/presentation/widgets/lesson_card.dart';
import 'package:itaaleem/features/courses/presentation/widgets/subscribe_request_sheet.dart';
import 'package:itaaleem/features/settings/presentation/providers/settings_providers.dart';
import 'package:itaaleem/features/teachers/domain/entities/teacher.dart';
import 'package:itaaleem/features/teachers/presentation/widgets/teacher_card.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_palette.dart';

/// Shown after tapping a "مادة" (a [CourseSection]) on the home tab: each of
/// the section's teachers as its own group — the teacher's name/photo as a
/// header, directly followed by *only their own* lectures, matched strictly
/// by `teacher_id` — never another teacher's, and never a shared/general
/// list.
///
/// `GET /courses/{id}` (the section's own lecture list) has been confirmed
/// via logging to never carry a `teacher_id` on any lecture at all — every
/// lecture comes back with just `id, title, duration_seconds, sort_order,
/// is_free_preview, is_locked, description, videos, pdfs, attachments`. So
/// [_TeacherLectureGroups] resolves each lecture's real teacher itself, one
/// `GET /lectures/{id}` at a time (that endpoint *does* send a nested
/// `teacher` object) via [lectureTeacherIdProvider] — skipped for locked,
/// non-preview lectures, since that endpoint 403s those and there's no way
/// to learn their teacher without unlocking them first. A lecture that
/// can't be attributed to any of the section's teachers this way lands in a
/// trailing "أخرى" group instead of disappearing. Falls back to the
/// section's full, ungrouped lecture list (see [_buildBody]) only when the
/// section has no teachers at all, or when literally nothing could be
/// attributed. Reads from the same `courseDetailsProvider(courseId)` the
/// home tab already primed, so this is normally an instant cache hit.
class SectionLessonsScreen extends ConsumerWidget {
  const SectionLessonsScreen({
    super.key,
    required this.courseId,
    required this.sectionId,
  });

  final int courseId;
  final int sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailsAsync = ref.watch(courseDetailsProvider(courseId));

    return Scaffold(
      body: detailsAsync.when(
        loading: () => Column(
          children: [
            const GradientBackBar(title: ''),
            const Expanded(child: CourseDetailsShimmer()),
          ],
        ),
        error: (error, stackTrace) => Column(
          children: [
            const GradientBackBar(title: ''),
            Expanded(
              child: ErrorView(
                message: 'تعذر تحميل الدروس، حاول مرة أخرى',
                retryLabel: 'إعادة المحاولة',
                onRetry: () => ref.invalidate(courseDetailsProvider(courseId)),
              ),
            ),
          ],
        ),
        data: (details) {
          final section = _findSection(details.sections, sectionId);
          if (section == null) {
            return Column(
              children: [
                const GradientBackBar(title: ''),
                Expanded(
                  child: ErrorView(
                    message: 'تعذر العثور على هذه المادة',
                    retryLabel: 'رجوع',
                    onRetry: () => context.pop(),
                  ),
                ),
              ],
            );
          }

          final primary = _primaryTeachersForSection(details, section);
          if (primary.isNotEmpty) {
            return _buildBody(context, ref, details, section, primary);
          }

          // The primary sources (nested section.teachers, or course.teachers
          // filtered by sectionIds) came up empty — try the standalone
          // teachers endpoint before giving up and falling through to the
          // section's plain lecture list.
          final fallbackAsync = ref.watch(
            sectionTeachersFallbackProvider(courseId),
          );
          return fallbackAsync.when(
            loading: () => Column(
              children: [
                GradientBackBar(title: section.title),
                const Expanded(child: ShimmerList(count: 5, thumbnailSize: 64)),
              ],
            ),
            error: (error, stackTrace) {
              if (kDebugMode) {
                debugPrint(
                  '[Teachers] GET /public/teachers?course_id=$courseId '
                  'failed: $error\n$stackTrace',
                );
              }
              return _buildBody(context, ref, details, section, const []);
            },
            data: (fallbackTeachers) {
              if (kDebugMode) {
                debugPrint(
                  'All teachers count (fallback /public/teachers): '
                  '${fallbackTeachers.length}',
                );
                for (final t in fallbackTeachers) {
                  debugPrint('Teacher: ${t.name}, sections: ${t.sectionIds}');
                }
              }
              final filtered = fallbackTeachers
                  .where((t) => t.sectionIds.contains(sectionId))
                  .toList();
              if (kDebugMode) {
                debugPrint('Filtered teachers count: ${filtered.length}');
                if (filtered.isEmpty &&
                    fallbackTeachers.every((t) => t.sectionIds.isEmpty)) {
                  debugPrint(
                    '[Teachers] /public/teachers also carries no sections '
                    'per teacher — see the raw JSON logged above from '
                    'CoursesRemoteDataSource to work out the real shape.',
                  );
                }
              }
              return _buildBody(context, ref, details, section, filtered);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    CourseDetails details,
    CourseSection section,
    List<Teacher> sectionTeachers,
  ) {
    // Only an explicit `true` from the server gates playback order — a
    // still-loading or errored settings fetch must never block a lecture
    // that would otherwise be playable.
    final sequentialMode =
        ref.watch(appSettingsProvider).valueOrNull?.sequentialMode ?? false;
    return Column(
      children: [
        GradientBackBar(title: section.title),
        Expanded(
          child: sectionTeachers.isNotEmpty
              ? _TeacherLectureGroups(
                  teachers: sectionTeachers,
                  lectures: section.lectures,
                  courseId: courseId,
                  courseTitle: details.title,
                  courseExams: details.exams,
                  sequentialMode: sequentialMode,
                )
              : _LecturesList(
                  courseId: courseId,
                  courseTitle: details.title,
                  lectures: section.lectures,
                  courseExams: details.exams,
                  sequentialMode: sequentialMode,
                ),
        ),
      ],
    );
  }

  CourseSection? _findSection(List<CourseSection> sections, int id) {
    for (final section in sections) {
      if (section.id == id) return section;
    }
    return null;
  }

  /// This section's teachers from `GET /courses/{id}` alone, i.e. only the
  /// ones actually tied to it via `section_teacher` — never the whole
  /// course's teacher list.
  ///
  /// 1. Prefers [CourseSection.teachers], nested directly on the section
  ///    object — the pivot's natural shape, already scoped server-side.
  /// 2. Falls back to filtering [CourseDetails.teachers] (the flat,
  ///    course-level list, "المفروض كل واحد فيه sections") by
  ///    [Teacher.sectionIds] — `teachers.where((t) => t.sectionIds.contains(section.id))`.
  /// 3. If *neither* shape carries any section-level data at all, returns
  ///    empty — the caller then tries [sectionTeachersFallbackProvider]
  ///    before giving up entirely.
  List<Teacher> _primaryTeachersForSection(
    CourseDetails details,
    CourseSection section,
  ) {
    if (kDebugMode) {
      debugPrint('Selected section ID: ${section.id}, title: ${section.title}');
      debugPrint('All teachers count: ${details.teachers.length}');
      for (final t in details.teachers) {
        debugPrint('Teacher: ${t.name}, sections: ${t.sectionIds}');
      }
    }

    List<Teacher> filtered;
    if (section.teachers.isNotEmpty) {
      filtered = section.teachers;
    } else {
      filtered = details.teachers
          .where((t) => t.sectionIds.contains(section.id))
          .toList();
    }

    if (kDebugMode) {
      debugPrint('Filtered teachers count: ${filtered.length}');
    }
    return filtered;
  }
}

/// One group per teacher who actually has at least one lecture resolved to
/// their id (via [lectureTeacherIdProvider], since the section's own lecture
/// list never carries `teacher_id` — see the class doc above) — a teacher
/// with zero matched lectures is skipped entirely rather than showing an
/// empty header. A lecture that can't be attributed to any of this
/// section's teachers (locked and unresolved, or resolved to some other
/// teacher entirely) lands in a trailing "أخرى" group instead of vanishing.
class _TeacherLectureGroups extends ConsumerWidget {
  const _TeacherLectureGroups({
    required this.teachers,
    required this.lectures,
    required this.courseId,
    required this.courseTitle,
    required this.courseExams,
    required this.sequentialMode,
  });

  final List<Teacher> teachers;
  final List<CourseLecture> lectures;
  final int courseId;
  final String courseTitle;
  final List<CourseExam> courseExams;
  final bool sequentialMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A locked, non-preview lecture 403s on GET /lectures/{id} — no point
    // spending a request to learn a teacher id we'll never get back.
    final resolvable = lectures.where((l) => !l.isLocked || l.isFreePreview);
    final resolutions = <int, AsyncValue<int?>>{
      for (final l in resolvable)
        l.id: ref.watch(lectureTeacherIdProvider(l.id)),
    };

    if (resolutions.values.any((r) => r.isLoading)) {
      return const ShimmerList(count: 5, thumbnailSize: 64);
    }

    final resolvedTeacherId = <int, int?>{
      for (final entry in resolutions.entries)
        entry.key: entry.value.valueOrNull,
    };

    if (kDebugMode) {
      debugPrint('All lectures count: ${lectures.length}');
      for (final l in lectures) {
        debugPrint(
          'Lecture: ${l.title}, teacher_id: ${resolvedTeacherId[l.id]}',
        );
      }
    }

    final groups = [
      for (final teacher in teachers)
        (
          teacher: teacher,
          // The correct filter: only this teacher's own lectures, matched
          // strictly by resolved id — never another teacher's.
          lectures: lectures
              .where((l) => resolvedTeacherId[l.id] == teacher.id)
              .toList(),
        ),
    ].where((group) => group.lectures.isNotEmpty).toList();

    if (groups.isEmpty) {
      // Nothing could be attributed to any of this section's teachers at
      // all (e.g. every lecture is still locked) — the plain list at least
      // keeps every lecture visible instead of an empty screen.
      return _LecturesList(
        courseId: courseId,
        courseTitle: courseTitle,
        lectures: lectures,
        courseExams: courseExams,
        sequentialMode: sequentialMode,
      );
    }

    final groupedIds = <int>{
      for (final g in groups)
        for (final l in g.lectures) l.id,
    };
    final other = lectures.where((l) => !groupedIds.contains(l.id)).toList();

    // Flattened once (cheap — just records, not widgets) so ListView.builder
    // can virtualize the actual lecture cards below instead of building
    // every teacher's whole lecture list up front.
    final rows = <_LessonRow>[];
    for (var g = 0; g < groups.length; g++) {
      rows.add(_LessonRow.header(groups[g].teacher, topGap: g > 0));
      final groupLectures = groups[g].lectures;
      for (var i = 0; i < groupLectures.length; i++) {
        rows.add(
          _LessonRow.lecture(
            lecture: groupLectures[i],
            siblings: groupLectures,
            index: i,
            animated: true,
          ),
        );
      }
    }
    if (other.isNotEmpty) {
      rows.add(const _LessonRow.sectionTitle('أخرى'));
      for (var i = 0; i < other.length; i++) {
        rows.add(
          _LessonRow.lecture(
            lecture: other[i],
            siblings: other,
            index: i,
            animated: false,
          ),
        );
      }
    }

    return ListView.builder(
      padding: const EdgeInsetsDirectional.all(16),
      itemCount: rows.length,
      itemBuilder: (context, index) => _buildRow(
        context,
        rows[index],
        index: index,
        courseId: courseId,
        courseTitle: courseTitle,
        courseExams: courseExams,
        sequentialMode: sequentialMode,
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    _LessonRow row, {
    required int index,
    required int courseId,
    required String courseTitle,
    required List<CourseExam> courseExams,
    required bool sequentialMode,
  }) {
    switch (row.kind) {
      case _LessonRowKind.header:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (row.topGap) const SizedBox(height: 22),
            _TeacherGroupHeader(teacher: row.teacher!),
            const SizedBox(height: 10),
          ],
        );
      case _LessonRowKind.sectionTitle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            Text(
              row.title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: context.palette.primary,
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      case _LessonRowKind.lecture:
        final lecture = row.lecture!;
        final siblings = row.siblings;
        final siblingIndex = row.siblingIndex;
        final card = LessonCard(
          lecture: lecture,
          sequentiallyLocked: isSequentiallyLocked(
            siblings,
            siblingIndex,
            sequentialMode,
          ),
          onTap: () => _onLectureTap(
            context,
            lecture: lecture,
            orderedLectures: siblings,
            index: siblingIndex,
            sequentialMode: sequentialMode,
            courseId: courseId,
            courseTitle: courseTitle,
            courseExams: courseExams,
          ),
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: row.animated
              ? FadeSlideIn(
                  delay: Duration(milliseconds: 40 * index.clamp(0, 16)),
                  child: card,
                )
              : card,
        );
    }
  }
}

enum _LessonRowKind { header, sectionTitle, lecture }

/// One virtualized row in [_TeacherLectureGroups]'s flattened list — either
/// a teacher header, a plain section title ("أخرى"), or a single lecture
/// card. Keeping this as plain data (not a built widget) is what lets
/// [ListView.builder] only build the rows actually on/near screen.
class _LessonRow {
  const _LessonRow.header(this.teacher, {required this.topGap})
    : kind = _LessonRowKind.header,
      title = null,
      lecture = null,
      siblings = const [],
      siblingIndex = -1,
      animated = false;

  const _LessonRow.sectionTitle(this.title)
    : kind = _LessonRowKind.sectionTitle,
      teacher = null,
      lecture = null,
      siblings = const [],
      siblingIndex = -1,
      topGap = false,
      animated = false;

  _LessonRow.lecture({
    required CourseLecture this.lecture,
    required this.siblings,
    required int index,
    required this.animated,
  }) : kind = _LessonRowKind.lecture,
       teacher = null,
       title = null,
       siblingIndex = index,
       topGap = false;

  final _LessonRowKind kind;
  final Teacher? teacher;
  final String? title;
  final CourseLecture? lecture;
  final List<CourseLecture> siblings;
  final int siblingIndex;
  final bool topGap;
  final bool animated;
}

/// A teacher group's header: small circular photo + name, e.g. "دكتور محمد
/// عامر" right above that teacher's own lecture list.
class _TeacherGroupHeader extends StatelessWidget {
  const _TeacherGroupHeader({required this.teacher});

  final Teacher teacher;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: context.palette.primary.withValues(alpha: 0.25),
            ),
          ),
          child: ClipOval(
            child: SizedBox(
              width: 40,
              height: 40,
              child: TeacherPhoto(
                url: teacher.photoUrl,
                iconSize: 20,
                boxSize: 40,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            teacher.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: context.palette.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// A section's full lecture list, unfiltered — shown directly when the
/// section has no teachers of its own.
class _LecturesList extends StatelessWidget {
  const _LecturesList({
    required this.courseId,
    required this.courseTitle,
    required this.lectures,
    required this.courseExams,
    required this.sequentialMode,
  });

  final int courseId;
  final String courseTitle;
  final List<CourseLecture> lectures;
  final List<CourseExam> courseExams;
  final bool sequentialMode;

  @override
  Widget build(BuildContext context) {
    if (lectures.isEmpty) {
      return const Center(child: EmptyLessonsView());
    }
    return ListView.builder(
      padding: const EdgeInsetsDirectional.all(16),
      itemCount: lectures.length,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FadeSlideIn(
          delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
          child: LessonCard(
            lecture: lectures[i],
            sequentiallyLocked: isSequentiallyLocked(
              lectures,
              i,
              sequentialMode,
            ),
            onTap: () => _onLectureTap(
              context,
              lecture: lectures[i],
              orderedLectures: lectures,
              index: i,
              sequentialMode: sequentialMode,
              courseId: courseId,
              courseTitle: courseTitle,
              courseExams: courseExams,
            ),
          ),
        ),
      ),
    );
  }
}

/// True when [sequentialMode] is on and the lecture before [index] in
/// [orderedLectures] (the same order the list renders in) hasn't been
/// completed yet. The first lecture in any list is always playable.
bool isSequentiallyLocked(
  List<CourseLecture> orderedLectures,
  int index,
  bool sequentialMode,
) {
  if (!sequentialMode || index == 0) return false;
  return !orderedLectures[index - 1].isCompleted;
}

/// Shared tap handler for a lecture row: a subscription lock takes priority
/// (shows the "اشترك"/enrollment sheet), then a sequential lock (a toast
/// asking to finish the previous lecture first), then the normal open.
void _onLectureTap(
  BuildContext context, {
  required CourseLecture lecture,
  required List<CourseLecture> orderedLectures,
  required int index,
  required bool sequentialMode,
  required int courseId,
  required String courseTitle,
  required List<CourseExam> courseExams,
}) {
  if (lecture.isLocked) {
    showSubscribeRequestSheet(
      context,
      courseId: courseId,
      courseTitle: courseTitle,
    );
    return;
  }
  if (isSequentiallyLocked(orderedLectures, index, sequentialMode)) {
    AppToast.showError(context, 'أكمل الدرس السابق أولاً');
    return;
  }
  context.push(
    '/lectures/${lecture.id}',
    extra: LectureNavArgs(
      title: lecture.title,
      courseExams: courseExams,
      courseId: courseId,
      courseTitle: courseTitle,
      orderedLectures: orderedLectures,
      currentIndex: index,
    ),
  );
}
