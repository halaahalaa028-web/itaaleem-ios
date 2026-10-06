import 'package:itaaleem/core/widgets/shimmer_loading.dart';
import 'package:flutter/material.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Skeleton list shown while [channelMessagesProvider] is loading,
/// matching [ChannelMessageCard]'s rough shape (an avatar/title row over a
/// couple of text lines).
class ChannelShimmer extends StatelessWidget {
  const ChannelShimmer({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: ListView.separated(
        padding: const EdgeInsetsDirectional.all(16),
        itemCount: itemCount,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) => const _ChannelCardSkeleton(),
      ),
    );
  }
}

class _ChannelCardSkeleton extends StatelessWidget {
  const _ChannelCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              ShimmerBox(width: 36, height: 36, borderRadius: 18),
              SizedBox(width: 10),
              Expanded(child: ShimmerBox(height: 14)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const ShimmerBox(height: 12),
          const SizedBox(height: AppSpacing.sm),
          ShimmerBox(height: 12, width: MediaQuery.sizeOf(context).width * 0.5),
        ],
      ),
    );
  }
}
