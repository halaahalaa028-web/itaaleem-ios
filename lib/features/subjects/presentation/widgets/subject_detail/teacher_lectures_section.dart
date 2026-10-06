import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';

/// One doctor's lectures inside a subject; [teacher] is `null` for the
/// "محاضرات عامة" group. Entries keep the lecture's index in the full
/// (sorted) list so numbering and progress stay the same as before.
class LessonTeacherGroup {
  LessonTeacherGroup(this.teacher);

  final SubjectTeacher? teacher;
  final lessons = <(int, SubjectLesson)>[];
}

/// Arabic-insensitive tokens: drops titles (د/، د.، دكتور), unifies
/// hamza/taa-marbuta/yaa forms and strips a leading "ال" — so the teacher
/// "د كرم ابو العسل" matches a title saying "كرم ابو عسل".
List<String> _tokens(String text) {
  final normalized = text
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'[ً-ْـ]'), '') // harakat, tatweel
      .replaceAll(RegExp(r'[^؀-ۿa-zA-Z0-9]+'), ' ')
      .toLowerCase();
  return [
    for (final raw in normalized.split(' '))
      if (raw.isNotEmpty && raw != 'د' && raw != 'دكتور' && raw != 'دكتوره')
        raw.length > 3 && raw.startsWith('ال') ? raw.substring(2) : raw,
  ];
}

/// [tokens] glued together with every "ال" removed — so spacing and the
/// definite article don't matter: "كرم ابوعسل", "كرم ابو عسل" and
/// "كرم أبو العسل" all become "كرمابوعسل".
String _compact(List<String> tokens) => tokens.join().replaceAll('ال', '');

/// Whether [title] mentions the doctor whose name tokens are [name]: every
/// name word appears (any order), or the space-less forms contain each other.
bool _mentions(List<String> title, List<String> name) {
  if (name.isEmpty) return false;
  if (title.toSet().containsAll(name)) return true;
  final compactName = _compact(name);
  return compactName.length >= 4 && _compact(title).contains(compactName);
}

/// Groups [lessons] by doctor:
/// 1. the lecture's own `teacher_id` / teacher name from the API;
/// 2. otherwise a doctor whose name appears in the lecture title;
/// 3. otherwise "محاضرات عامة" (last).
/// Doctors with no lectures are left out.
List<LessonTeacherGroup> groupLessonsByTeacher(
  List<SubjectLesson> lessons,
  List<SubjectTeacher> teachers,
) {
  final groups = [for (final t in teachers) LessonTeacherGroup(t)];
  final general = LessonTeacherGroup(null);
  final teacherTokens = [for (final t in teachers) _tokens(t.name)];

  LessonTeacherGroup? byApi(SubjectLesson lesson) {
    if (lesson.teacherId != null) {
      for (final g in groups) {
        if (g.teacher!.id == lesson.teacherId) return g;
      }
    }
    final name = lesson.teacherName;
    if (name != null) {
      final tokens = _tokens(name);
      for (final g in groups) {
        if (_mentions(_tokens(g.teacher!.name), tokens)) return g;
      }
      // A doctor the subject's list doesn't know about yet.
      final extra = LessonTeacherGroup(
        SubjectTeacher(id: lesson.teacherId, name: name),
      );
      groups.add(extra);
      teacherTokens.add(tokens);
      return extra;
    }
    return null;
  }

  LessonTeacherGroup? byTitle(SubjectLesson lesson) {
    final title = _tokens(lesson.title);
    for (var i = 0; i < teachers.length; i++) {
      if (_mentions(title, teacherTokens[i])) return groups[i];
    }
    return null;
  }

  for (var i = 0; i < lessons.length; i++) {
    final lesson = lessons[i];
    (byApi(lesson) ?? byTitle(lesson) ?? general).lessons.add((i, lesson));
  }
  return [
    for (final g in groups)
      if (g.lessons.isNotEmpty) g,
    if (general.lessons.isNotEmpty) general,
  ];
}

/// A collapsible doctor section (header "د/ … (8)" + its lecture tiles) as
/// one sliver.
class TeacherLecturesSection extends StatefulWidget {
  const TeacherLecturesSection({
    super.key,
    required this.group,
    required this.itemBuilder,
    this.initiallyExpanded = true,
  });

  final LessonTeacherGroup group;

  /// Builds the tile for `(indexInFullList, lesson)`.
  final Widget Function(BuildContext context, int index, SubjectLesson lesson)
  itemBuilder;
  final bool initiallyExpanded;

  @override
  State<TeacherLecturesSection> createState() => _TeacherLecturesSectionState();
}

class _TeacherLecturesSectionState extends State<TeacherLecturesSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final teacher = widget.group.teacher;
    final photo = teacher?.photoUrl;
    final lessons = widget.group.lessons;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.lg,
                bottom: AppSpacing.sm,
              ),
              child: Material(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: scheme.secondaryContainer,
                          foregroundImage: photo != null
                              ? CachedNetworkImageProvider(photo)
                              : null,
                          child: Icon(
                            teacher == null
                                ? Icons.category_rounded
                                : Icons.person_rounded,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            '${teacher?.name ?? 'محاضرات عامة'} '
                            '(${lessons.length})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_more_rounded,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_expanded)
            SliverList.separated(
              itemCount: lessons.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final (index, lesson) = lessons[i];
                return widget.itemBuilder(context, index, lesson);
              },
            ),
        ],
      ),
    );
  }
}
