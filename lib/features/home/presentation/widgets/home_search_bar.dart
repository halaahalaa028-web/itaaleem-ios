import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';
import 'package:itaaleem/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:itaaleem/features/subjects/presentation/screens/lesson_detail_screen.dart';

/// Every subject with its lectures, for local search. Lectures come from
/// each subject's (TTL-cached) detail call; a failing subject simply
/// contributes no lectures. Loaded once, the first time the student types.
final _homeSearchIndexProvider = FutureProvider.autoDispose<List<Subject>>((
  ref,
) async {
  final subjects = await ref.watch(subjectsListProvider.future);
  return Future.wait([
    for (final s in subjects)
      ref
          .watch(subjectDetailsProvider(s.id).future)
          .then(
            (d) => Subject(
              id: s.id,
              name: s.name,
              iconUrl: s.iconUrl,
              teacherId: s.teacherId,
              teacherName: s.teacherName,
              teacherPhotoUrl: s.teacherPhotoUrl,
              teachers: s.teachers.isNotEmpty ? s.teachers : d.teachers,
              lessons: d.lessons,
            ),
          )
          .catchError((Object _) => s),
  ]);
});

String _normalize(String text) => text
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'[ً-ْـ]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase()
    .trim();

enum _ResultKind { subject, teacher, lecture }

class _Result {
  const _Result(
    this.kind,
    this.title,
    this.subtitle,
    this.subject, [
    this.lesson,
  ]);

  final _ResultKind kind;
  final String title;
  final String? subtitle;
  final Subject subject;
  final SubjectLesson? lesson;
}

List<_Result> _search(List<Subject> subjects, String query) {
  final q = _normalize(query);
  if (q.isEmpty) return const [];
  final subjectHits = <_Result>[];
  final teacherHits = <_Result>[];
  final lectureHits = <_Result>[];
  for (final s in subjects) {
    final teachers = [
      ...s.teachers.map((t) => t.name),
      if (s.teachers.isEmpty && s.teacherName != null) s.teacherName!,
    ];
    if (_normalize(s.name).contains(q)) {
      subjectHits.add(
        _Result(_ResultKind.subject, s.name, teachers.join('، '), s),
      );
    }
    for (final t in teachers) {
      if (_normalize(t).contains(q)) {
        teacherHits.add(_Result(_ResultKind.teacher, t, s.name, s));
      }
    }
    for (final l in s.lessons) {
      if (_normalize(l.title).contains(q)) {
        lectureHits.add(_Result(_ResultKind.lecture, l.title, s.name, s, l));
      }
    }
  }
  return [...subjectHits, ...teacherHits, ...lectureHits].take(30).toList();
}

/// Always-visible search field on the home screen: filters subjects,
/// doctors and lectures locally and lists the matches right under it.
class HomeSearchBar extends ConsumerStatefulWidget {
  const HomeSearchBar({super.key});

  @override
  ConsumerState<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends ConsumerState<HomeSearchBar> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    FocusScope.of(context).unfocus();
  }

  void _open(_Result r) {
    FocusScope.of(context).unfocus();
    final lesson = r.lesson;
    if (lesson != null) {
      context.push<void>(
        '/lessons/${lesson.id}',
        extra: LessonDetailNavArgs(lesson: lesson, subjectId: r.subject.id),
      );
    } else {
      context.push<void>('/subject-detail/${r.subject.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final searching = _query.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          onChanged: (v) => setState(() => _query = v),
          textInputAction: TextInputAction.search,
          style: text.bodyLarge?.copyWith(fontFamily: 'Cairo'),
          decoration: InputDecoration(
            hintText: 'ابحث عن مادة، محاضرة، أو دكتور...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: searching
                ? IconButton(
                    tooltip: 'مسح',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: _clear,
                  )
                : null,
            filled: true,
            fillColor: scheme.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (searching) ...[
          const SizedBox(height: AppSpacing.sm),
          _Results(query: _query, onOpen: _open),
        ],
      ],
    );
  }
}

class _Results extends ConsumerWidget {
  const _Results({required this.query, required this.onOpen});

  final String query;
  final ValueChanged<_Result> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final async = ref.watch(_homeSearchIndexProvider);
    // While lectures load, subjects/doctors from the list call still match.
    final subjects =
        async.valueOrNull ?? ref.watch(subjectsListProvider).valueOrNull;

    if (subjects == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final results = _search(subjects, query);

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: results.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                async.isLoading ? 'جاري البحث...' : 'لا توجد نتائج',
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            )
          : Column(
              children: [
                for (final (i, r) in results.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: Icon(switch (r.kind) {
                      _ResultKind.subject => Icons.menu_book_rounded,
                      _ResultKind.teacher => Icons.person_rounded,
                      _ResultKind.lecture => Icons.play_circle_rounded,
                    }, color: scheme.primary),
                    title: Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: r.subtitle == null || r.subtitle!.isEmpty
                        ? null
                        : Text(
                            r.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                    trailing: const Icon(Icons.chevron_left_rounded),
                    onTap: () => onOpen(r),
                  ),
                ],
              ],
            ),
    );
  }
}
