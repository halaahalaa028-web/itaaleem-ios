import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/features/courses/domain/entities/course_details.dart';
import 'package:itaaleem/features/teachers/domain/entities/teacher.dart';
import 'package:itaaleem/features/teachers/presentation/widgets/teacher_card.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// One lecture row: a video/PDF thumbnail (or a plain type icon when
/// there's none), the title (with the lecture's own teacher shown as a
/// small circular avatar right beside it, when resolvable), duration,
/// video/PDF/free-preview badges, and a trailing lock/completed/chevron
/// icon. Used by `SectionLessonsScreen`, both for its plain lecture list
/// (when a section has no teachers of its own) and inside each teacher's
/// own lecture group.
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.lecture,
    required this.onTap,
    this.teacher,
    this.sequentiallyLocked = false,
  });

  final CourseLecture lecture;
  final VoidCallback onTap;
  final Teacher? teacher;

  /// True when [lecture] is only locked because the previous lecture in its
  /// list hasn't been completed yet (`sequential_mode` setting) — shown with
  /// the same lock icon as [CourseLecture.isLocked], but [onTap] surfaces a
  /// different message for it (see `SectionLessonsScreen`).
  final bool sequentiallyLocked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isLocked = lecture.isLocked || sequentiallyLocked;
    final dimAlpha = isLocked ? 0.45 : 1.0;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LessonThumbnail(
            lecture: lecture,
            dimAlpha: dimAlpha,
            locked: isLocked,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (teacher != null) ...[
                      ClipOval(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: TeacherPhoto(
                            url: teacher!.photoUrl,
                            iconSize: 13,
                            boxSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        lecture.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface.withValues(
                            alpha: dimAlpha,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (lecture.durationLabel != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 13,
                            color: colorScheme.onSurface.withValues(
                              alpha: 0.5 * dimAlpha,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            lecture.durationLabel!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.55 * dimAlpha,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (lecture.hasVideo)
                      _Badge(
                        label: 'فيديو',
                        icon: Icons.videocam_rounded,
                        color: context.palette.primary,
                      ),
                    if (lecture.hasPdf)
                      _Badge(
                        label: 'PDF',
                        icon: Icons.picture_as_pdf_rounded,
                        color: context.palette.warning,
                      ),
                    if (lecture.isFreePreview)
                      _Badge(
                        label: 'معاينة مجانية',
                        icon: Icons.lock_open_rounded,
                        color: context.palette.success,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isLocked)
            Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            )
          else if (lecture.isCompleted)
            Icon(
              Icons.check_circle_rounded,
              color: context.palette.success,
              size: 20,
            )
          else
            Icon(
              Icons.chevron_left_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
        ],
      ),
    );
  }
}

/// Left-side visual for a lesson row: the primary video's thumbnail when
/// there is one, with a small play badge overlaid; a plain type icon on a
/// tinted circle otherwise (PDF-only or locked-with-no-preview lectures).
class _LessonThumbnail extends StatelessWidget {
  const _LessonThumbnail({
    required this.lecture,
    required this.dimAlpha,
    required this.locked,
  });

  final CourseLecture lecture;
  final double dimAlpha;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = lecture.thumbnailUrl;
    if (thumbnailUrl == null || thumbnailUrl.isEmpty) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: context.palette.primary.withValues(alpha: 0.1 * dimAlpha),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          locked ? Icons.lock_rounded : _iconOf(lecture.type),
          color: context.palette.primary.withValues(alpha: dimAlpha),
          size: 20,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: SizedBox(
        width: 52,
        height: 52,
        child: Opacity(
          opacity: dimAlpha,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: thumbnailUrl,
                fit: BoxFit.cover,
                memCacheWidth: 104,
                memCacheHeight: 104,
                placeholder: (context, url) => Container(
                  color: context.palette.primary.withValues(alpha: 0.1),
                ),
                errorWidget: (context, url, error) => Container(
                  color: context.palette.primary.withValues(alpha: 0.1),
                  child: Icon(
                    _iconOf(lecture.type),
                    color: context.palette.primary,
                    size: 20,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                ),
              ),
              Center(
                child: Icon(
                  locked ? Icons.lock_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconOf(LectureType type) {
    switch (type) {
      case LectureType.video:
        return Icons.play_circle_outline_rounded;
      case LectureType.pdf:
        return Icons.picture_as_pdf_rounded;
      case LectureType.other:
        return Icons.description_rounded;
    }
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Muted, not the raw brand/accent hue — a tinted-on-surface mix reads
    // calmer than a saturated color chip at this small a size.
    final muted = Color.lerp(
      color,
      Theme.of(context).colorScheme.onSurface,
      0.35,
    )!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: muted),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: muted,
              fontWeight: FontWeight.w700,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared "no lectures yet" placeholder for both the subject screen (no
/// teachers case) and a teacher's own lecture list.
class EmptyLessonsView extends StatelessWidget {
  const EmptyLessonsView({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'لا توجد دروس بعد',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
