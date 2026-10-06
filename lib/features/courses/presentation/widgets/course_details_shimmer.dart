import 'package:itaaleem/core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Skeleton shown while [courseDetailsProvider] is loading.
class CourseDetailsShimmer extends StatelessWidget {
  const CourseDetailsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(AppSpacing.screenHorizontal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ShimmerBox(height: 10),
            const SizedBox(height: AppSpacing.xl),
            for (var i = 0; i < 3; i++) ...[
              const ShimmerBox(height: 72, borderRadius: 18),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
