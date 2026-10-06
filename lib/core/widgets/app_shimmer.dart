import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Loading skeletons: one [AppShimmer] animates a gradient sweep over every
/// [ShimmerBlock] below it, so a whole skeleton shares a single
/// AnimationController instead of one per box. Colors come from the theme
/// (`palette.shimmerBase/Highlight`), so skeletons follow dark mode.
class AppShimmer extends StatefulWidget {
  const AppShimmer({super.key, required this.child});

  final Widget child;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final base = palette.shimmerBase;
    final highlight = palette.shimmerHighlight;
    // Sweep in the reading direction (right → left in Arabic).
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final t = rtl ? 1 - _controller.value : _controller.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [(t - 0.3).clamp(0.0, 1.0), t, (t + 0.3).clamp(0.0, 1.0)],
            ).createShader(bounds),
            child: child,
          );
        },
      ),
    );
  }
}

/// A rounded placeholder rectangle; place inside an [AppShimmer].
class ShimmerBlock extends StatelessWidget {
  const ShimmerBlock({
    super.key,
    this.width,
    required this.height,
    this.radius = AppRadius.sm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.shimmerBase,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// The card frame every skeleton sits in — the same surface, radius and
/// hairline as `AppCard`, so loading → loaded doesn't jump.
class ShimmerCardFrame extends StatelessWidget {
  const ShimmerCardFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }
}

/// Skeleton of a list card: thumbnail + two text lines.
class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key, this.thumbnailSize = 56});

  final double thumbnailSize;

  @override
  Widget build(BuildContext context) {
    return ShimmerCardFrame(
      child: Row(
        children: [
          ShimmerBlock(
            width: thumbnailSize,
            height: thumbnailSize,
            radius: AppRadius.md,
          ),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(height: 14),
                SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  widthFactor: 0.6,
                  child: ShimmerBlock(height: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A non-scrolling column of [ShimmerCard]s for list screens.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.count = 5, this.thumbnailSize = 56});

  final int count;
  final double thumbnailSize;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, _) =>
            const SizedBox(height: AppSpacing.listItemSpacing),
        itemBuilder: (_, _) => ShimmerCard(thumbnailSize: thumbnailSize),
      ),
    );
  }
}

/// Skeleton of a details page: a hero block, a title, a few text lines and
/// a couple of list cards — for screens that load one item (a lesson, an
/// exam, a center) rather than a list.
class ShimmerDetail extends StatelessWidget {
  const ShimmerDetail({super.key, this.heroHeight = 180, this.cards = 3});

  final double heroHeight;
  final int cards;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          if (heroHeight > 0) ...[
            ShimmerBlock(height: heroHeight, radius: AppRadius.card),
            const SizedBox(height: AppSpacing.sectionSpacing),
          ],
          const FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 0.7,
            child: ShimmerBlock(height: 22),
          ),
          const SizedBox(height: AppSpacing.md),
          const ShimmerBlock(height: 12),
          const SizedBox(height: AppSpacing.sm),
          const FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 0.85,
            child: ShimmerBlock(height: 12),
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),
          for (var i = 0; i < cards; i++) ...[
            const ShimmerCard(thumbnailSize: 44),
            const SizedBox(height: AppSpacing.listItemSpacing),
          ],
        ],
      ),
    );
  }
}

/// Skeleton of the subjects grid: icon tile + title per cell.
class ShimmerSubjectGrid extends StatelessWidget {
  const ShimmerSubjectGrid({
    super.key,
    this.count = 6,
    this.crossAxisCount = 2,
  });

  final int count;
  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: GridView.builder(
        padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: AppSpacing.gridSpacing,
          crossAxisSpacing: AppSpacing.gridSpacing,
          childAspectRatio: 1.1,
        ),
        itemBuilder: (_, _) => const ShimmerCardFrame(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShimmerBlock(width: 48, height: 48, radius: AppRadius.md),
              SizedBox(height: AppSpacing.md),
              ShimmerBlock(width: 90, height: 14),
              SizedBox(height: AppSpacing.sm),
              ShimmerBlock(width: 56, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
