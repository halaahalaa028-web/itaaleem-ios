import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/fade_slide_in.dart';
import 'package:itaaleem/core/widgets/section_header.dart';

/// One titled list on the subject screen (المحاضرات / الملفات / …) as a
/// single sliver: a [SectionHeader] with the item count, then a lazily
/// built list. Callers leave the section out entirely when it's empty.
class SubjectSection extends StatelessWidget {
  const SubjectSection({
    super.key,
    required this.title,
    required this.icon,
    required this.itemCount,
    required this.itemBuilder,
    this.onSeeAll,
    this.showCount = true,
  });

  final String title;
  final IconData icon;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final VoidCallback? onSeeAll;
  final bool showCount;

  /// Only the first few items cascade in — enough for the first screenful,
  /// without replaying the animation on every item scrolled back into view.
  static const _animatedItems = 6;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      sliver: SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: SectionHeader(
              title: title,
              icon: icon,
              count: showCount ? itemCount : null,
              onSeeAll: onSeeAll,
              padding: const EdgeInsets.fromLTRB(
                0,
                AppSpacing.xl,
                0,
                AppSpacing.sm,
              ),
            ),
          ),
          SliverList.separated(
            itemCount: itemCount,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final child = itemBuilder(context, index);
              if (index >= _animatedItems) return child;
              return FadeSlideIn(
                delay: Duration(milliseconds: 40 * index),
                child: child,
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The shared card shell of every subject-screen tile: surface, hairline
/// border, rounded corners and an ink ripple. [highlighted] tints it with
/// the brand color (e.g. the "آخر مشاهدة" lecture).
class SubjectTileShell extends StatelessWidget {
  const SubjectTileShell({
    super.key,
    required this.child,
    this.onTap,
    this.highlighted = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AppRadius.lg);
    return Material(
      color: highlighted
          ? Color.alphaBlend(
              scheme.primary.withValues(alpha: 0.06),
              scheme.surface,
            )
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: highlighted
              ? scheme.primary.withValues(alpha: 0.55)
              : scheme.outlineVariant.withValues(alpha: 0.6),
          width: highlighted ? 1.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          child: child,
        ),
      ),
    );
  }
}

/// The small square icon badge leading file/exam/assignment tiles.
class SubjectTileIcon extends StatelessWidget {
  const SubjectTileIcon({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

/// Muted "icon + text" bits under a tile's title (duration, size, …).
class SubjectTileMeta extends StatelessWidget {
  const SubjectTileMeta({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: color),
        ),
      ],
    );
  }
}

/// Title text style shared by every subject-screen tile.
const subjectTileTitleStyle = TextStyle(
  fontFamily: 'Cairo',
  fontSize: 14,
  height: 1.4,
  fontWeight: FontWeight.w700,
);
