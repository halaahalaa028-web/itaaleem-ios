import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/status_badge.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/subject_section.dart';

enum ExamTileStatus { notTaken, passed, failed }

class ExamTileData {
  const ExamTileData({
    required this.title,
    required this.questionsCount,
    required this.passPercentage,
    this.durationMinutes,
    this.isLocked = false,
  });

  final String title;
  final int questionsCount;
  final int? durationMinutes;
  final int passPercentage;
  final bool isLocked;
}

/// One exam: title, "20 سؤال • 30 دقيقة • نجاح 60%" and its status
/// (لم يُحل / ناجح / راسب, or مقفول).
class ExamTile extends StatelessWidget {
  const ExamTile({
    super.key,
    required this.data,
    this.status = ExamTileStatus.notTaken,
    this.bestPercentage,
    this.onTap,
  });

  final ExamTileData data;
  final ExamTileStatus status;

  /// The best past score, shown next to ناجح/راسب.
  final double? bestPercentage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final score = bestPercentage == null ? '' : ' ${bestPercentage!.round()}%';
    final badge = data.isLocked
        ? const StatusBadge(type: StatusType.locked, label: 'مقفول')
        : switch (status) {
            ExamTileStatus.passed => StatusBadge(
              type: StatusType.success,
              label: 'ناجح$score',
            ),
            ExamTileStatus.failed => StatusBadge(
              type: StatusType.error,
              label: 'راسب$score',
            ),
            ExamTileStatus.notTaken => const StatusBadge(
              type: StatusType.info,
              label: 'لم يُحل',
              showIcon: false,
            ),
          };

    return SubjectTileShell(
      onTap: data.isLocked ? null : onTap,
      child: Opacity(
        opacity: data.isLocked ? 0.6 : 1,
        child: Row(
          children: [
            SubjectTileIcon(icon: Icons.quiz_rounded, color: scheme.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: subjectTileTitleStyle,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.xs,
                    children: [
                      SubjectTileMeta(
                        icon: Icons.help_outline_rounded,
                        label: '${data.questionsCount} سؤال',
                      ),
                      if (data.durationMinutes != null)
                        SubjectTileMeta(
                          icon: Icons.timer_outlined,
                          label: '${data.durationMinutes} دقيقة',
                        ),
                      SubjectTileMeta(
                        icon: Icons.flag_outlined,
                        label: 'نجاح ${data.passPercentage}%',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            badge,
          ],
        ),
      ),
    );
  }
}
