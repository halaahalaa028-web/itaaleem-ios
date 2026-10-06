import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_progress_bar.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/lesson_access.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_detail/subject_section.dart';

enum LectureTileStatus { completed, inProgress, notStarted, locked }

/// Everything a [LectureTile] shows — built from a real `SubjectLesson`
/// (plus its saved progress) or from the demo session's dummy lectures.
class LectureTileData {
  const LectureTileData({
    required this.number,
    required this.title,
    required this.status,
    this.subtitle,
    this.durationLabel,
    this.progress = 0,
    this.isLastWatched = false,
    this.isFree = false,
    this.hasExam = false,
  });

  /// The lecture has at least one exam (shown as a "امتحان" mark).
  final bool hasExam;

  final int number;
  final String title;
  final String? subtitle;
  final String? durationLabel;
  final LectureTileStatus status;

  /// 0.0–1.0, shown as a thin bar while [status] is in progress.
  final double progress;
  final bool isLastWatched;
  final bool isFree;
}

class LectureTile extends StatelessWidget {
  const LectureTile({super.key, required this.data, this.onTap});

  final LectureTileData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = data.status == LectureTileStatus.locked;
    final inProgress = data.status == LectureTileStatus.inProgress;

    final metaParts = <Widget>[
      if (data.durationLabel != null)
        SubjectTileMeta(
          icon: Icons.schedule_rounded,
          label: data.durationLabel!,
        ),
      if (data.subtitle != null)
        SubjectTileMeta(icon: Icons.notes_rounded, label: data.subtitle!),
      if (data.isFree) const FreeLessonBadge(),
      if (data.hasExam)
        _InlineLabel(label: 'فيها امتحان', color: scheme.tertiary),
      if (data.status == LectureTileStatus.completed)
        _InlineLabel(label: 'مكتملة', color: context.palette.success),
      if (inProgress)
        _InlineLabel(
          label: 'شاهدت ${(data.progress * 100).round()}%',
          color: scheme.primary,
        ),
    ];

    return SubjectTileShell(
      onTap: onTap,
      highlighted: data.isLastWatched,
      child: Opacity(
        opacity: locked ? 0.6 : 1,
        child: Row(
          children: [
            _NumberBadge(number: data.number, status: data.status),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.isLastWatched) ...[
                    const _LastWatchedBadge(),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  Text(
                    data.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: subjectTileTitleStyle,
                  ),
                  if (metaParts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.md,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: metaParts,
                    ),
                  ],
                  if (inProgress) ...[
                    const SizedBox(height: AppSpacing.sm),
                    AppProgressBar(progress: data.progress, height: 4),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _StatusIcon(status: data.status),
          ],
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  const _NumberBadge({required this.number, required this.status});

  final int number;
  final LectureTileStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final success = context.palette.success;
    final (Color bg, Color fg) = switch (status) {
      LectureTileStatus.completed => (success.withValues(alpha: 0.14), success),
      LectureTileStatus.inProgress => (scheme.primary, scheme.onPrimary),
      LectureTileStatus.notStarted => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      LectureTileStatus.locked => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final LectureTileStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color, String tooltip) = switch (status) {
      LectureTileStatus.completed => (
        Icons.check_circle_rounded,
        context.palette.success,
        'مكتملة',
      ),
      LectureTileStatus.inProgress => (
        Icons.play_circle_fill_rounded,
        scheme.primary,
        'جارية',
      ),
      LectureTileStatus.notStarted => (
        Icons.play_circle_outline_rounded,
        scheme.outline,
        'لم تبدأ',
      ),
      LectureTileStatus.locked => (Icons.lock_rounded, scheme.outline, 'مقفلة'),
    };
    return Tooltip(
      message: tooltip,
      child: Icon(icon, color: color, size: 28),
    );
  }
}

class _LastWatchedBadge extends StatelessWidget {
  const _LastWatchedBadge();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_rounded, size: 12, color: scheme.onPrimary),
          const SizedBox(width: 3),
          Text(
            'آخر مشاهدة',
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: scheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLabel extends StatelessWidget {
  const _InlineLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      ),
    );
  }
}
