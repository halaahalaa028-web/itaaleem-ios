import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';

/// Loading placeholder laid out like the subject screen: header, progress
/// card and a few lecture rows.
class SubjectDetailSkeleton extends StatelessWidget {
  const SubjectDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 250 + MediaQuery.paddingOf(context).top,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            flexibleSpace: const FlexibleSpaceBar(
              background: _HeaderSkeleton(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.screenHorizontal),
            sliver: SliverToBoxAdapter(
              child: AppShimmer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Card(
                      child: Row(
                        children: [
                          const ShimmerBlock(
                            width: 74,
                            height: 74,
                            radius: AppRadius.full,
                          ),
                          const SizedBox(width: AppSpacing.base),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
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
                    const SizedBox(height: AppSpacing.xl),
                    const ShimmerBlock(width: 110, height: 16),
                    const SizedBox(height: AppSpacing.md),
                    for (var i = 0; i < 4; i++) ...[
                      const _LectureRowSkeleton(),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderSkeleton extends StatefulWidget {
  const _HeaderSkeleton();

  @override
  State<_HeaderSkeleton> createState() => _HeaderSkeletonState();
}

/// The header sits on the brand color, where [AppShimmer]'s grey sweep
/// would look off — its blocks gently pulse instead.
class _HeaderSkeletonState extends State<_HeaderSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.45,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = scheme.onPrimary.withValues(alpha: 0.18);
    Widget bar(double? width, double height, [double radius = AppRadius.sm]) =>
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: block,
            borderRadius: BorderRadius.circular(radius),
          ),
        );

    return DecoratedBox(
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
      child: FadeTransition(
        opacity: _controller,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  bar(58, 58, AppRadius.lg),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(160, 20),
                        const SizedBox(height: AppSpacing.sm),
                        bar(100, 12),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              bar(double.infinity, 11),
              const SizedBox(height: 6),
              bar(220, 11),
              const SizedBox(height: AppSpacing.base),
              bar(double.infinity, 52, AppRadius.button),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _LectureRowSkeleton extends StatelessWidget {
  const _LectureRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Row(
        children: [
          ShimmerBlock(width: 40, height: 40, radius: AppRadius.full),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(height: 14),
                SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  widthFactor: 0.45,
                  child: ShimmerBlock(height: 11),
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.md),
          ShimmerBlock(width: 28, height: 28, radius: AppRadius.full),
        ],
      ),
    );
  }
}
