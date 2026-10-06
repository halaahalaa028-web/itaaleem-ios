import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/status_badge.dart';
import 'package:itaaleem/features/exams/domain/entities/exam.dart';
import 'package:itaaleem/features/exams/presentation/providers/exams_providers.dart';

/// The exams under a lecture's video (subject → lecture → video → exams),
/// from `GET /lectures/{id}/exams`. Each card shows questions, duration,
/// status and score; tapping opens the exam screen (`/exams/{id}`). Renders
/// nothing at all (not even [header]) while loading or when there are none.
class LectureExamsSection extends ConsumerWidget {
  const LectureExamsSection({
    super.key,
    required this.lectureId,
    this.header,
  });

  final int lectureId;

  /// Shown above the cards only when there are exams.
  final Widget? header;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lectureExamsProvider(lectureId));

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          _Message(
            icon: Icons.cloud_off_rounded,
            text: failureOf(error).message,
            action: TextButton(
              onPressed: () => ref.invalidate(lectureExamsProvider(lectureId)),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      ),
      data: (exams) {
        if (exams.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?header,
            for (final exam in exams)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _LectureExamCard(exam: exam),
              ),
          ],
        );
      },
    );
  }
}

class _LectureExamCard extends ConsumerWidget {
  const _LectureExamCard({required this.exam});

  final ExamSummary exam;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    // Status / score from this student's attempts; quietly "لم يُحل" if the
    // results call isn't available.
    final attempts = ref.watch(examResultsProvider(exam.id)).valueOrNull;
    final best = attempts == null || attempts.isEmpty
        ? null
        : attempts.reduce((a, b) => a.percentage >= b.percentage ? a : b);

    final (StatusType type, String label) = exam.isLocked
        ? (StatusType.locked, 'مقفول')
        : best == null
        ? (StatusType.info, 'لم يُحل')
        : best.isPassed
        ? (StatusType.success, 'ناجح')
        : (StatusType.error, 'راسب');

    final meta = [
      '${exam.questionsCount} سؤال',
      if (exam.durationMinutes != null) '${exam.durationMinutes} دقيقة',
      if (best != null) 'الدرجة: ${best.percentage.round()}%',
    ].join(' • ');

    return Card(
      elevation: 1,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: exam.isLocked || exam.id <= 0
            ? null
            : () => context.push('/exams/${exam.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.quiz_rounded,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      meta,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(type: type, label: label),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
