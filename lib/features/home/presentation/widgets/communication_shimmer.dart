import 'package:itaaleem/core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';

/// Skeleton grid shown while [appSettingsProvider] is loading on the
/// "التواصل" tab, matching its contact-card grid layout.
class CommunicationShimmer extends StatelessWidget {
  const CommunicationShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.5,
        ),
        itemBuilder: (context, index) => const ShimmerBox(borderRadius: 20),
      ),
    );
  }
}
