import 'package:flutter/material.dart';
import 'package:itaaleem/core/utils/open_file_in_app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/app/router/route_args.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/core/widgets/section_header.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/exams/presentation/providers/exams_providers.dart';
import 'package:itaaleem/features/home/presentation/providers/content_refresh.dart';
import 'package:itaaleem/features/subjects/data/dummy_subjects.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';
import 'package:itaaleem/features/subjects/presentation/providers/subject_progress_provider.dart';
import 'package:itaaleem/features/subjects/presentation/providers/subjects_providers.dart';
import 'package:itaaleem/features/subjects/presentation/screens/lesson_detail_screen.dart';
import 'package:itaaleem/features/subjects/presentation/utils/pdf_download.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/lesson_access.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/attachment_tile.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/lecture_tile.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/subject_detail_header.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/subject_detail_skeleton.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/subject_progress_card.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/subject_section.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/teacher_lectures_section.dart';
import 'package:itaaleem/features/teachers/presentation/providers/teachers_providers.dart';
import 'package:itaaleem/features/teachers/presentation/widgets/teacher_card.dart';

/// One subject: a collapsing header (with "متابعة التعلم"), the student's
/// progress, then its lectures, files, exams and assignments as one
/// scrolling page — sections with nothing in them are left out. A demo
/// ("دخول تجريبي") session renders the dummy content in the same layout; a
/// real session loads `GET /subjects/{id}`.
class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoSessionProvider);
    return isDemo
        ? _DemoSubjectDetail(subjectId: subjectId)
        : _RealSubjectDetail(subjectId: subjectId);
  }
}

/// Bottom breathing room under the last section.
class _BottomSpacer extends StatelessWidget {
  const _BottomSpacer();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: AppSpacing.xxl + MediaQuery.paddingOf(context).bottom,
      ),
    );
  }
}

class _Padded extends StatelessWidget {
  const _Padded({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.base,
        AppSpacing.screenHorizontal,
        0,
      ),
      sliver: SliverToBoxAdapter(child: child),
    );
  }
}

// ============================================================================
// Real (GET /subjects/{id})
// ============================================================================

class _RealSubjectDetail extends ConsumerWidget {
  const _RealSubjectDetail({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(subjectDetailsProvider(subjectId));

    return subjectAsync.when(
      loading: () => const SubjectDetailSkeleton(),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('المادة')),
        body: ErrorView(
          message: failureOf(error).message,
          retryLabel: 'إعادة المحاولة',
          onRetry: () => ref.invalidate(subjectDetailsProvider(subjectId)),
        ),
      ),
      data: (subject) => _RealSubjectBody(subject: subject),
    );
  }
}

class _RealSubjectBody extends ConsumerWidget {
  const _RealSubjectBody({required this.subject});

  final Subject subject;

  int get _id => subject.id;

  Future<void> _openLesson(
    BuildContext context,
    WidgetRef ref,
    SubjectLesson lesson,
  ) async {
    await context.push<void>(
      '/lessons/${lesson.id}',
      extra: LessonDetailNavArgs(
        lesson: lesson,
        subjectId: _id,
        subjectExams: subject.exams,
      ),
    );
    // Whatever was watched there should show up here straight away.
    if (context.mounted) ref.invalidate(subjectLessonsProgressProvider(_id));
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(subjectLessonsProgressProvider(_id));
    ref.invalidate(subjectExamsProvider(_id));
    ref.invalidate(examResultsProvider);
    await refreshAll(ref, subjectId: _id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessons = [...subject.lessons]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final progressAsync = ref.watch(subjectLessonsProgressProvider(_id));
    final summary = SubjectProgressSummary.from(
      lessons,
      progressAsync.valueOrNull ?? const {},
    );

    // The detail call's lessons fallback can drop `icon_url` — the list
    // call (normally still cached from the previous screen) has it too.
    final iconUrl =
        subject.iconUrl ??
        ref.watch(
          subjectsListProvider.select(
            (s) =>
                s.valueOrNull?.where((e) => e.id == _id).firstOrNull?.iconUrl,
          ),
        );
    final filesCount = ref.watch(
      attachmentsProvider(_id).select((s) => s.valueOrNull?.length ?? 0),
    );
    final lessonsCount = lessons.length > subject.lessonsCount
        ? lessons.length
        : subject.lessonsCount;
    // The detail call may omit `teachers`; the list call has them.
    final teachers = subject.teachers.isNotEmpty
        ? subject.teachers
        : ref.watch(
                subjectsListProvider.select(
                  (s) => s.valueOrNull
                      ?.where((e) => e.id == _id)
                      .firstOrNull
                      ?.teachers,
                ),
              ) ??
              const <SubjectTeacher>[];

    Widget lectureTile(BuildContext context, int index, SubjectLesson lesson) {
      return _LectureTileWithExam(
        lesson: lesson,
        data: _lectureData(ref, index, lesson, summary),
        onTap: () => _openLesson(context, ref, lesson),
      );
    }

    final target = summary.continueLesson;
    final targetIndex = target == null ? -1 : lessons.indexOf(target);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        edgeOffset: kToolbarHeight + MediaQuery.paddingOf(context).top,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SubjectDetailHeader(
              subjectId: _id,
              title: subject.name,
              description: subject.description,
              imageUrl: iconUrl,
              teacher: _TeacherLine(subjectId: _id),
              stats: [
                SubjectHeaderStat(
                  icon: Icons.play_circle_outline_rounded,
                  label: '$lessonsCount محاضرة',
                ),
                if (filesCount > 0)
                  SubjectHeaderStat(
                    icon: Icons.folder_outlined,
                    label: '$filesCount ملف',
                  ),
              ],
              continueLabel: summary.hasStarted
                  ? 'متابعة التعلم'
                  : 'ابدأ التعلم',
              continueCaption: target == null
                  ? null
                  : 'المحاضرة ${targetIndex + 1}: ${target.title}',
              onContinue: target == null
                  ? null
                  : () => _openLesson(context, ref, target),
              onRefresh: () => _refresh(ref),
            ),
            if (lessons.isNotEmpty)
              _Padded(
                child: progressAsync.hasValue
                    ? SubjectProgressCard(
                        completed: summary.completedCount,
                        total: summary.total,
                        started: summary.hasStarted,
                      )
                    : const _ProgressCardPlaceholder(),
              ),
            if (lessons.isNotEmpty && teachers.isEmpty)
              SubjectSection(
                title: 'المحاضرات',
                icon: Icons.play_lesson_rounded,
                itemCount: lessons.length,
                itemBuilder: (context, index) =>
                    lectureTile(context, index, lessons[index]),
              ),
            // One collapsible section per doctor, then "محاضرات عامة".
            if (lessons.isNotEmpty && teachers.isNotEmpty)
              for (final group in groupLessonsByTeacher(lessons, teachers))
                TeacherLecturesSection(
                  key: ValueKey(
                    'teacher-${group.teacher?.id ?? group.teacher?.name}',
                  ),
                  group: group,
                  itemBuilder: lectureTile,
                ),
            _RealFilesSection(subjectId: _id),
            // Exams now live inside each lecture (LectureExamsSection).
            if (lessons.isEmpty)
              const _Padded(child: _NoContentNote()),
            const _BottomSpacer(),
          ],
        ),
      ),
    );
  }

  LectureTileData _lectureData(
    WidgetRef ref,
    int index,
    SubjectLesson lesson,
    SubjectProgressSummary summary,
  ) {
    final watched = summary.inProgress[lesson.id];
    final status = isLessonLocked(ref, lesson)
        ? LectureTileStatus.locked
        : summary.completedIds.contains(lesson.id)
        ? LectureTileStatus.completed
        : watched != null
        ? LectureTileStatus.inProgress
        : LectureTileStatus.notStarted;
    return LectureTileData(
      number: index + 1,
      title: lesson.title,
      durationLabel: lesson.durationMinutes == null
          ? null
          : '${lesson.durationMinutes} دقيقة',
      status: status,
      progress: watched ?? 0,
      isLastWatched: summary.lastWatchedId == lesson.id,
      isFree: lesson.isFree,
    );
  }
}

/// This subject's teacher, from `GET /teachers` filtered by
/// [Teacher.sectionIds] containing [subjectId] — renders nothing while
/// loading, on error, or when no teacher is tagged for this subject, since
/// it's a nice-to-have rather than essential content.
class _TeacherLine extends ConsumerWidget {
  const _TeacherLine({required this.subjectId});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacher = ref.watch(
      teachersProvider.select(
        (s) => s.valueOrNull
            ?.where((t) => t.sectionIds.contains(subjectId))
            .firstOrNull,
      ),
    );
    if (teacher == null) return const SizedBox.shrink();
    final spec = teacher.displaySpecialization;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox.square(
              dimension: 22,
              child: TeacherPhoto(
                url: teacher.photoUrl,
                iconSize: 14,
                boxSize: 22,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              spec.isEmpty ? teacher.name : '${teacher.name} • $spec',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `GET /attachments?subject_id=` — hidden while loading and when empty.
class _RealFilesSection extends ConsumerWidget {
  const _RealFilesSection({required this.subjectId});

  final int subjectId;

  Future<void> _open(BuildContext context, SubjectAttachment file) async {
    if (file.isPdf) {
      await context.push<void>(
        lessonPdfPath,
        extra: LessonPdfArgs(
          title: file.name,
          pdfUrl: file.url,
          downloadable: file.isDownloadable,
        ),
      );
      return;
    }
    await openFileInApp(
      context,
      file.url,
      title: file.name,
      type: file.type,
      downloadable: file.isDownloadable,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(attachmentsProvider(subjectId));

    return attachmentsAsync.when(
      loading: () => const SliverToBoxAdapter(),
      error: (error, _) => _SectionErrorSliver(
        title: 'الملفات',
        icon: Icons.folder_rounded,
        message: failureOf(error).message,
        onRetry: () => ref.invalidate(attachmentsProvider(subjectId)),
      ),
      data: (files) {
        if (files.isEmpty) return const SliverToBoxAdapter();
        return SubjectSection(
          title: 'الملفات',
          icon: Icons.folder_rounded,
          itemCount: files.length,
          itemBuilder: (context, index) {
            final file = files[index];
            return AttachmentTile(
              data: AttachmentTileData(
                name: file.name,
                type: file.type ?? (file.isPdf ? 'PDF' : null),
                sizeLabel: file.sizeLabel,
              ),
              onOpen: () => _open(context, file),
              onDownload: !file.isDownloadable
                  ? null
                  : file.isPdf
                  ? () => downloadPdf(
                      context,
                      ref,
                      url: file.url,
                      title: file.name,
                    )
                  : () => _open(context, file),
            );
          },
        );
      },
    );
  }
}

/// A [LectureTile] marked "فيها امتحان" when the lecture has exams — from
/// the lesson's own `exams_count`, else `GET /lectures/{id}/exams`.
class _LectureTileWithExam extends ConsumerWidget {
  const _LectureTileWithExam({
    required this.lesson,
    required this.data,
    required this.onTap,
  });

  final SubjectLesson lesson;
  final LectureTileData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasExam = lesson.examsCount != null
        ? lesson.examsCount! > 0
        : ref.watch(lectureHasExamsProvider(lesson.id)).valueOrNull ?? false;
    return LectureTile(
      data: LectureTileData(
        number: data.number,
        title: data.title,
        status: data.status,
        subtitle: data.subtitle,
        durationLabel: data.durationLabel,
        progress: data.progress,
        isLastWatched: data.isLastWatched,
        isFree: data.isFree,
        hasExam: hasExam,
      ),
      onTap: onTap,
    );
  }
}

/// A section whose list failed to load: its header plus a retry row, so a
/// transient error doesn't silently hide it.
class _SectionErrorSliver extends StatelessWidget {
  const _SectionErrorSliver({
    required this.title,
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              title: title,
              icon: icon,
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.xl,
                0,
                AppSpacing.sm,
              ),
            ),
            SubjectTileShell(
              child: Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: scheme.error),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      message,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCardPlaceholder extends StatelessWidget {
  const _ProgressCardPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: const AppShimmer(
        child: Row(
          children: [
            ShimmerBlock(width: 74, height: 74, radius: AppRadius.full),
            SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBlock(width: 120, height: 14),
                  SizedBox(height: AppSpacing.sm),
                  ShimmerBlock(width: 170, height: 11),
                  SizedBox(height: AppSpacing.md),
                  ShimmerBlock(height: 6, radius: AppRadius.full),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoContentNote extends StatelessWidget {
  const _NoContentNote();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          Icon(Icons.video_library_outlined, size: 48, color: scheme.outline),
          const SizedBox(height: AppSpacing.md),
          Text(
            'مفيش محاضرات متاحة بعد',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Demo (دخول تجريبي) — dummy content, same layout
// ============================================================================

const _demoLectures = [
  LectureTileData(
    number: 1,
    title: 'المحاضرة الأولى',
    subtitle: 'مقدمة',
    durationLabel: '30 دقيقة',
    status: LectureTileStatus.completed,
  ),
  LectureTileData(
    number: 2,
    title: 'المحاضرة الثانية',
    subtitle: 'الأساسيات',
    durationLabel: '45 دقيقة',
    status: LectureTileStatus.completed,
  ),
  LectureTileData(
    number: 3,
    title: 'المحاضرة الثالثة',
    subtitle: 'التطبيق العملي',
    durationLabel: '40 دقيقة',
    status: LectureTileStatus.inProgress,
    progress: 0.4,
    isLastWatched: true,
  ),
  LectureTileData(
    number: 4,
    title: 'المحاضرة الرابعة',
    subtitle: 'مقفولة',
    durationLabel: '35 دقيقة',
    status: LectureTileStatus.locked,
  ),
  LectureTileData(
    number: 5,
    title: 'المحاضرة الخامسة',
    subtitle: 'مقفولة',
    durationLabel: '50 دقيقة',
    status: LectureTileStatus.locked,
  ),
  LectureTileData(
    number: 6,
    title: 'المحاضرة السادسة',
    subtitle: 'مقفولة',
    durationLabel: '30 دقيقة',
    status: LectureTileStatus.locked,
  ),
];

const _demoFiles = [
  AttachmentTileData(
    name: 'ملخص الفصل الأول',
    type: 'PDF',
    sizeLabel: '2.5 MB',
  ),
  AttachmentTileData(name: 'تمارين إضافية', type: 'PDF', sizeLabel: '1.8 MB'),
  AttachmentTileData(
    name: 'المراجعة النهائية',
    type: 'PDF',
    sizeLabel: '3.1 MB',
  ),
];

class _DemoSubjectDetail extends StatelessWidget {
  const _DemoSubjectDetail({required this.subjectId});

  final int subjectId;

  void _showDemoNote(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'دي نسخة تجريبية — المحتوى الكامل متاح بعد تفعيل حسابك',
            textAlign: TextAlign.center,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final subject = dummySubjectById(subjectId);
    if (subject == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('المادة غير موجودة')),
      );
    }
    final current = _demoLectures.firstWhere(
      (l) => l.status == LectureTileStatus.inProgress,
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SubjectDetailHeader(
            subjectId: subject.id,
            title: subject.name,
            description: subject.description,
            teacher: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(Icons.person_rounded, size: 16),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      subject.teacher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            stats: [
              SubjectHeaderStat(
                icon: Icons.play_circle_outline_rounded,
                label: '${subject.lecturesTotal} محاضرة',
              ),
              SubjectHeaderStat(
                icon: Icons.folder_outlined,
                label: '${_demoFiles.length} ملف',
              ),
            ],
            continueCaption: 'المحاضرة ${current.number}: ${current.title}',
            onContinue: () => _showDemoNote(context),
          ),
          _Padded(
            child: SubjectProgressCard(
              completed: subject.lecturesDone,
              total: subject.lecturesTotal,
              started: subject.progress > 0,
            ),
          ),
          SubjectSection(
            title: 'المحاضرات',
            icon: Icons.play_lesson_rounded,
            itemCount: _demoLectures.length,
            itemBuilder: (context, index) => LectureTile(
              data: _demoLectures[index],
              onTap: () => _showDemoNote(context),
            ),
          ),
          SubjectSection(
            title: 'الملفات',
            icon: Icons.folder_rounded,
            itemCount: _demoFiles.length,
            itemBuilder: (context, index) => AttachmentTile(
              data: _demoFiles[index],
              onOpen: () => _showDemoNote(context),
            ),
          ),
          const _BottomSpacer(),
        ],
      ),
    );
  }
}
