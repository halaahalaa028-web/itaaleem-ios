import 'package:itaaleem/features/home/presentation/providers/content_refresh.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/app_progress_bar.dart';
import 'package:itaaleem/core/widgets/app_empty_state.dart';
import 'package:itaaleem/core/widgets/app_error_state.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/core/widgets/status_badge.dart';
import 'package:itaaleem/features/subscriptions/presentation/providers/subscription_providers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/subjects/data/dummy_subjects.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';
import 'package:itaaleem/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_icon.dart';
import 'package:itaaleem/features/subscriptions/presentation/widgets/subject_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_palette.dart';

/// "موادي" tab: every subject the student is studying this term, each
/// opening its own lectures/files/exams on [SubjectDetailScreen]. A demo
/// ("دخول تجريبي") session renders [dummySubjects] exactly as before; a
/// real session loads `GET /subjects`.
class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'موادي',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: isDemo
          ? const _DemoSubjectsList()
          : RefreshIndicator(
              onRefresh: () => refreshAll(ref),
              child: const _RealSubjectsList(),
            ),
    );
  }
}

class _DemoSubjectsList extends StatelessWidget {
  const _DemoSubjectsList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: dummySubjects.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.base),
      itemBuilder: (context, index) => KeyedSubtree(
        key: ValueKey(index),
        child: FadeSlideIn.staggered(
          index: index,
          child: _DemoSubjectCard(subject: dummySubjects[index]),
        ),
      ),
    );
  }
}

class _RealSubjectsList extends ConsumerWidget {
  const _RealSubjectsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsListProvider);
    ref.watch(prefetchFirstSubjectProvider);

    return subjectsAsync.when(
      loading: () => const ShimmerList(count: 5, thumbnailSize: 60),
      error: (error, _) => _FillScrollable(
        child: AppErrorState(
          message: failureOf(error).message,
          onRetry: () => ref.invalidate(subjectsListProvider),
        ),
      ),
      data: (subjects) {
        if (subjects.isEmpty) {
          return const _FillScrollable(
            child: AppEmptyState(
              icon: Icons.menu_book_rounded,
              title: 'مفيش مواد متاحة حالياً',
              subtitle: 'المواد اللي هتشترك فيها هتظهر هنا',
            ),
          );
        }
        final groups = _groupByTeacher(subjects);
        var index = 0;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            _SubjectsHeader(count: subjects.length),
            for (final group in groups) ...[
              const SizedBox(height: AppSpacing.lg),
              _TeacherHeader(group: group),
              for (final subject in group.subjects)
                Padding(
                  key: ValueKey('${group.teacherName}-${subject.id}'),
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: FadeSlideIn.staggered(
                    index: (index++).clamp(0, 8),
                    child: SubjectLockGate(
                      subjectId: subject.id,
                      subjectName: subject.name,
                      child: _SubjectCard(subject: subject),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _TeacherGroup {
  _TeacherGroup(this.teacherName, this.teacherPhotoUrl);

  final String? teacherName;
  final String? teacherPhotoUrl;
  final subjects = <Subject>[];
}

/// One section per doctor (by id, else name), in first-seen order. A
/// subject taught by several doctors (`teachers[]`) appears under each of
/// them; subjects without a doctor go last under "مواد عامة".
List<_TeacherGroup> _groupByTeacher(List<Subject> subjects) {
  final groups = <String, _TeacherGroup>{};
  final others = _TeacherGroup(null, null);
  for (final s in subjects) {
    final teachers = s.teachers.isNotEmpty
        ? s.teachers
        : [
            if (s.teacherName != null)
              SubjectTeacher(
                id: s.teacherId,
                name: s.teacherName!,
                photoUrl: s.teacherPhotoUrl,
              ),
          ];
    if (teachers.isEmpty) {
      others.subjects.add(s);
      continue;
    }
    final seen = <String>{};
    for (final t in teachers) {
      final key = t.id?.toString() ?? t.name;
      if (!seen.add(key)) continue;
      groups
          .putIfAbsent(key, () => _TeacherGroup(t.name, t.photoUrl))
          .subjects
          .add(s);
    }
  }
  return [...groups.values, if (others.subjects.isNotEmpty) others];
}

/// Keeps pull-to-refresh working on the empty / error states.
class _FillScrollable extends StatelessWidget {
  const _FillScrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(height: constraints.maxHeight, child: child),
      ),
    );
  }
}

class _SubjectsHeader extends StatelessWidget {
  const _SubjectsHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(Icons.auto_stories_rounded, color: scheme.primary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'كل موادك في مكان واحد',
            style: text.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Text(
            '$count مادة',
            style: text.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({required this.group});

  final _TeacherGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final name = group.teacherName;
    final photo = group.teacherPhotoUrl;
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: scheme.secondaryContainer,
          foregroundImage: photo != null
              ? CachedNetworkImageProvider(photo)
              : null,
          child: Icon(
            name == null ? Icons.category_rounded : Icons.person_rounded,
            color: scheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                // API names already carry the title ("د/ محمد عامر").
                name ?? 'مواد عامة',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(
                '${group.subjects.length} مادة',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  const _SubjectCard({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.lg);
    final status = ref
        .watch(subjectSubscriptionProvider(subject.id))
        .valueOrNull;
    final progress = subject.progressPercent;

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/subject-detail/${subject.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              SubjectIcon(
                iconUrl: subject.iconUrl,
                seed: subject.id,
                name: subject.name,
                size: 60,
                iconSize: 30,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        // Only for paid subjects — free ones need no badge.
                        if (status != null && status.requiresSubscription) ...[
                          const SizedBox(width: AppSpacing.sm),
                          status.hasAccess
                              ? const StatusBadge(
                                  type: StatusType.success,
                                  label: 'فعّال',
                                )
                              : StatusBadge(
                                  type: StatusType.error,
                                  label: status.subscription == null
                                      ? 'غير مشترك'
                                      : 'منتهي',
                                ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_outline_rounded,
                          size: 15,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${subject.lessonsCount} محاضرة',
                          style: text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (progress != null) ...[
                          const Spacer(),
                          Text(
                            '${progress.round()}%',
                            style: text.labelSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AppProgressBar(progress: progress / 100, height: 6),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoSubjectCard extends StatelessWidget {
  const _DemoSubjectCard({required this.subject});

  final DummySubject subject;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: context.palette.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md + 2),
                ),
                child: Icon(
                  subject.icon,
                  color: context.palette.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.name,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subject.teacher,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Text(
                          '${subject.lecturesTotal} محاضرة',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 11,
                            color: context.palette.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(subject.progress * 100).round()}%',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.palette.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    AppProgressBar(progress: subject.progress),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.primary(
            'متابعة التعلم',
            onPressed: () => context.push('/subject-detail/${subject.id}'),
          ),
        ],
      ),
    );
  }
}
