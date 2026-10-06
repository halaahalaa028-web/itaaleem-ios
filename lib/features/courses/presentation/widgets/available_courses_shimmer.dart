import 'package:itaaleem/core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_radius.dart';

/// Skeleton list (or, with [grid], skeleton 2-column grid matching the home
/// tab's [SubjectCard] layout) shown while [availableCoursesProvider] /
/// [homeSubjectsProvider] is loading.
class AvailableCoursesShimmer extends StatelessWidget {
  const AvailableCoursesShimmer({
    super.key,
    this.itemCount = 4,
    this.grid = false,
  });

  final int itemCount;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHigh;
    final border = Border.all(
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
    );

    if (grid) {
      return ShimmerLoading(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (context, index) => Container(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: border,
            ),
          ),
        ),
      );
    }

    return ShimmerLoading(
      child: Column(
        children: List.generate(
          itemCount,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 14),
            height: 128,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: border,
            ),
          ),
        ),
      ),
    );
  }
}
