import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/features/subjects/presentation/widgets/subject_icon.dart';

/// One "12 محاضرة"-style pill in [SubjectDetailHeader].
class SubjectHeaderStat {
  const SubjectHeaderStat({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// The subject screen's collapsing [SliverAppBar]: the subject's image (or
/// a brand gradient) behind its name, description, teacher, stats and the
/// "متابعة التعلم" button. Collapses to a plain bar with the name.
class SubjectDetailHeader extends StatelessWidget {
  const SubjectDetailHeader({
    super.key,
    required this.subjectId,
    required this.title,
    this.description,
    this.imageUrl,
    this.teacher,
    this.stats = const [],
    this.continueLabel = 'متابعة التعلم',
    this.continueCaption,
    this.onContinue,
    this.onRefresh,
  });

  final int subjectId;
  final String title;
  final String? description;
  final String? imageUrl;

  /// Shown under the title (e.g. the teacher's name/photo).
  final Widget? teacher;
  final List<SubjectHeaderStat> stats;
  final String continueLabel;

  /// Small line under the button's label (e.g. the target lecture's title).
  final String? continueCaption;

  /// The button is omitted when null (e.g. no lectures yet).
  final VoidCallback? onContinue;
  final VoidCallback? onRefresh;

  bool get _hasDescription =>
      description != null && description!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);

    // Roughly the content's own height, so the expanded bar fits it at any
    // text scale (the content is bottom-anchored, never clipped mid-text).
    final contentHeight =
        78 +
        (_hasDescription ? 52 : 0) +
        (stats.isEmpty ? 0 : 42) +
        (onContinue == null ? 0 : (continueCaption == null ? 64 : 76));
    final expandedHeight =
        kToolbarHeight + topInset + AppSpacing.base + contentHeight * scale;
    final minHeight = kToolbarHeight + topInset;

    return SliverAppBar(
      pinned: true,
      stretch: true,
      expandedHeight: expandedHeight,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      surfaceTintColor: Colors.transparent,
      actions: [
        if (onRefresh != null)
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: onRefresh,
          ),
      ],
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final range = expandedHeight - minHeight;
          final t = range <= 0
              ? 0.0
              : ((constraints.maxHeight - minHeight) / range).clamp(0.0, 1.0);
          final contentOpacity = ((t - 0.4) / 0.6).clamp(0.0, 1.0);
          final titleOpacity = (1 - t * 2.5).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              _HeaderBackground(imageUrl: imageUrl),
              // Collapsed bar title — fades in as the content fades out.
              PositionedDirectional(
                top: topInset,
                start: 56,
                end: onRefresh == null ? 16 : 56,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: titleOpacity,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: AppSpacing.lg,
                end: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Opacity(
                  opacity: contentOpacity,
                  child: IgnorePointer(
                    ignoring: contentOpacity < 0.5,
                    child: _HeaderContent(header: this),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl;
    final gradient = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            scheme.primary,
            Color.alphaBlend(
              scheme.primaryContainer.withValues(alpha: 0.35),
              scheme.primary,
            ),
          ],
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        gradient,
        if (url != null && url.isNotEmpty)
          CachedNetworkImage(
            imageUrl: url,
            memCacheWidth:
                (MediaQuery.sizeOf(context).width *
                        MediaQuery.devicePixelRatioOf(context))
                    .round(),
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 250),
            errorWidget: (context, url, error) => const SizedBox.shrink(),
          ),
        // Soft decorative rings — give the plain gradient some depth.
        PositionedDirectional(
          top: -60,
          end: -50,
          child: _Ring(size: 200, color: scheme.onPrimary),
        ),
        PositionedDirectional(
          bottom: -80,
          start: -40,
          child: _Ring(size: 180, color: scheme.onPrimary),
        ),
        // Scrim keeping the text readable over any image.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                scheme.primary.withValues(alpha: url == null ? 0 : 0.45),
                scheme.primary.withValues(alpha: url == null ? 0.1 : 0.92),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.08), width: 22),
      ),
    );
  }
}

class _HeaderContent extends StatelessWidget {
  const _HeaderContent({required this.header});

  final SubjectDetailHeader header;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPrimary = scheme.onPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg + 2),
                border: Border.all(
                  color: onPrimary.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: SubjectIcon(
                    iconUrl: header.imageUrl,
                    seed: header.subjectId,
                    name: header.title,
                    size: 54,
                    iconSize: 26,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    header.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 22,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: onPrimary,
                    ),
                  ),
                  if (header.teacher != null)
                    DefaultTextStyle.merge(
                      style: TextStyle(
                        color: onPrimary.withValues(alpha: 0.85),
                      ),
                      child: IconTheme.merge(
                        data: IconThemeData(
                          color: onPrimary.withValues(alpha: 0.85),
                        ),
                        child: header.teacher!,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (header._hasDescription) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            header.description!.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13,
              height: 1.6,
              color: onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
        if (header.stats.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [for (final stat in header.stats) _StatPill(stat: stat)],
          ),
        ],
        if (header.onContinue != null) ...[
          const SizedBox(height: AppSpacing.base),
          _ContinueButton(
            label: header.continueLabel,
            caption: header.continueCaption,
            onPressed: header.onContinue!,
          ),
        ],
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.stat});

  final SubjectHeaderStat stat;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: onPrimary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: onPrimary.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(stat.icon, size: 15, color: onPrimary),
          const SizedBox(width: 6),
          Text(
            stat.label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.label,
    required this.onPressed,
    this.caption,
  });

  final String label;
  final String? caption;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.surface,
          foregroundColor: scheme.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                size: 20,
                color: scheme.onPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 18, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
