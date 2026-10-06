import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/presentation/providers/exams_providers.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/app/router/route_args.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// `GET /exams/{id}`: title, duration, question/attempt counts, and the
/// "بدء الامتحان" action that kicks off `POST /exams/{id}/start`.
class ExamDetailsScreen extends ConsumerWidget {
  const ExamDetailsScreen({super.key, required this.examId});

  final int examId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (examId <= 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل الامتحان')),
        body: ErrorView(
          message: 'لا يمكن فتح هذا الامتحان',
          retryLabel: 'رجوع',
          onRetry: () => Navigator.of(context).maybePop(),
        ),
      );
    }
    final detailsAsync = ref.watch(examDetailsProvider(examId));

    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل الامتحان')),
      body: detailsAsync.when(
        loading: () => const ShimmerDetail(heroHeight: 160),
        error: (error, stackTrace) => ErrorView(
          // 404 → "الامتحان غير متوفر", 429 → rate limit, 422 → server text.
          message: failureOf(error).message,
          retryLabel: 'إعادة المحاولة',
          onRetry: () => ref.invalidate(examDetailsProvider(examId)),
        ),
        data: (details) => _ExamDetailsBody(details: details, examId: examId),
      ),
    );
  }
}

class _ExamDetailsBody extends ConsumerStatefulWidget {
  const _ExamDetailsBody({required this.details, required this.examId});

  final ExamDetails details;

  /// The route's id — used when the details body didn't carry its own.
  final int examId;

  int get id => details.id > 0 ? details.id : examId;

  @override
  ConsumerState<_ExamDetailsBody> createState() => _ExamDetailsBodyState();
}

class _ExamDetailsBodyState extends ConsumerState<_ExamDetailsBody> {
  bool _starting = false;

  Future<void> _startExam() async {
    setState(() => _starting = true);
    // `POST /exams/{id}/start` opens an attempt on servers that support it,
    // otherwise this is just `GET /exams/{id}/questions`.
    final useCase = ref.read(startExamUseCaseProvider);
    final result = await useCase(widget.id);
    if (!mounted) return;
    setState(() => _starting = false);

    switch (result) {
      case Ok<ExamStart>(:final value):
        if (value.questions.isEmpty) {
          AppToast.showError(context, 'لا توجد أسئلة في هذا الامتحان بعد');
          return;
        }
        context.push<void>(
          examTakingPath,
          extra: ExamTakingArgs(
            examId: widget.id,
            title: widget.details.title,
            durationMinutes:
                value.durationMinutes ?? widget.details.durationMinutes,
            questions: value.questions,
            attemptId: value.attemptId,
            startedAt: value.startedAt,
            allowReview: widget.details.allowReview,
          ),
        );
      case Err<ExamStart>(:final failure):
        AppToast.showError(
          context,
          failure.message.isNotEmpty
              ? failure.message
              : 'حدث خطأ ما، حاول مرة أخرى',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canStart = details.hasAttemptsLeft;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: context.palette.brandGradient,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: context.palette.onPrimary.withValues(
                      alpha: 0.24,
                    ),
                    child: Icon(
                      Icons.quiz_rounded,
                      color: context.palette.onPrimary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    details.title,
                    textAlign: TextAlign.center,
                    style: textTheme.titleLarge?.copyWith(
                      color: context.palette.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Expanded(
              child: ListView(
                children: [
                  _StatTile(
                    icon: Icons.timer_rounded,
                    label: 'مدة الامتحان',
                    value: details.durationMinutes != null
                        ? '${details.durationMinutes} دقيقة'
                        : 'بدون وقت محدد',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (details.questionsCount > 0) ...[
                    _StatTile(
                      icon: Icons.help_outline_rounded,
                      label: 'عدد الأسئلة',
                      value: '${details.questionsCount}',
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  _StatTile(
                    icon: Icons.emoji_events_rounded,
                    label: 'درجة النجاح',
                    value: details.passScore != null
                        ? '${details.passScore!.round()}٪'
                        : '—',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _StatTile(
                    icon: Icons.repeat_rounded,
                    label: 'المحاولات',
                    value: details.attemptsAllowed != null
                        ? '${details.attemptsUsed} من ${details.attemptsAllowed}'
                        : 'غير محدودة',
                  ),
                  if (!canStart) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsetsDirectional.all(
                        AppSpacing.cardPadding,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(
                          alpha: 0.4,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'لقد استنفدت عدد المحاولات المسموح بها',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (details.allowReview) _LastAttemptReview(details: details),
            FilledButton(
              onPressed: (!canStart || _starting) ? null : _startExam,
              child: _starting
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          context.palette.onPrimary,
                        ),
                      ),
                    )
                  : const Text('بدء الامتحان'),
            ),
          ],
        ),
      ),
    );
  }
}

/// "مراجعة آخر محاولة" — shown once the student has a past attempt.
class _LastAttemptReview extends ConsumerWidget {
  const _LastAttemptReview({required this.details});

  final ExamDetails details;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attempts =
        ref.watch(examResultsProvider(details.id)).valueOrNull ?? const [];
    final valid = attempts.where((a) => a.id > 0).toList()
      ..sort(
        (a, b) =>
            (b.takenAt ?? DateTime(0)).compareTo(a.takenAt ?? DateTime(0)),
      );
    if (valid.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.fact_check_rounded),
        label: Text('مراجعة آخر محاولة (${valid.first.percentage.round()}٪)'),
        onPressed: () => context.push<void>(
          examReviewPath,
          extra: ExamReviewArgs(
            title: details.title,
            attemptId: valid.first.id,
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsetsDirectional.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
