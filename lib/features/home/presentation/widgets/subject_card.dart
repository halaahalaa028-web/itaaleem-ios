import 'package:cached_network_image/cached_network_image.dart';
import 'package:itaaleem/features/home/presentation/providers/home_subjects_provider.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// One "مادة" card in the home tab's 2-column grid: a fixed 16:9 cover
/// image (the section's own thumbnail if the backend sends one, else the
/// parent course's cover, else a purple gradient placeholder), bold title,
/// lecture count and progress bar underneath.
///
/// An [AppCard] with a very light brand-tinted gradient fading into
/// `surface`, so subject tiles stand out a little from plain list cards.
class SubjectCard extends StatelessWidget {
  const SubjectCard({super.key, required this.subject, required this.onTap});

  final HomeSubject subject;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final palette = context.palette;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.primarySurface.withValues(alpha: palette.isDark ? 0.25 : 0.6),
          palette.surface,
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _SubjectImage(url: subject.thumbnailUrl),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  subject.section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 12,
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        subject.courseTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          color: colorScheme.onSurface.withValues(alpha: 0.55),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: palette.primarySurface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.play_circle_outline_rounded,
                        size: 13,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${subject.lecturesCount} درس',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    Text(
                      '${subject.progressPercent.round()}٪',
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _GradientProgressBar(percent: subject.progressPercent),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    subject.progressPercent > 0 ? 'أكمل' : 'ابدأ',
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 0-100 progress bar filled with a primary -> accent gradient.
class _GradientProgressBar extends StatelessWidget {
  const _GradientProgressBar({required this.percent});

  final double percent;

  @override
  Widget build(BuildContext context) {
    final fraction = percent.clamp(0, 100) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: SizedBox(
        height: 6,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(color: context.palette.primarySurface),
            ),
            Positioned.fill(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: fraction.toDouble(),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectImage extends StatelessWidget {
  const _SubjectImage({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return const _SubjectImagePlaceholder();
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      memCacheWidth: 480,
      placeholder: (context, url) => const _SubjectImagePlaceholder(),
      errorWidget: (context, url, error) => const _SubjectImagePlaceholder(),
    );
  }
}

class _SubjectImagePlaceholder extends StatelessWidget {
  const _SubjectImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.7)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.menu_book_rounded,
          color: scheme.onPrimary.withValues(alpha: 0.7),
          size: 34,
        ),
      ),
    );
  }
}
