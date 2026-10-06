import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:itaaleem/app/router/app_router.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/theme/app_palette.dart';
import 'package:itaaleem/core/widgets/app_button.dart';
import 'package:itaaleem/core/widgets/app_card.dart';
import 'package:itaaleem/core/widgets/empty_state.dart';
import 'package:itaaleem/core/widgets/section_header.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';
import 'package:itaaleem/core/widgets/app_toast.dart';
import 'package:itaaleem/features/center/data/models/center_review.dart';
import 'package:itaaleem/features/center/presentation/providers/reviews_providers.dart';
import 'package:itaaleem/features/center/presentation/widgets/review_widgets.dart';
import 'package:itaaleem/core/theme/app_radius.dart';

/// Edit/delete menu for the student's own review — shared by the home
/// section and the full reviews screen.
class OwnReviewMenu extends ConsumerWidget {
  const OwnReviewMenu({
    super.key,
    required this.centerId,
    required this.review,
  });

  final int centerId;
  final CenterReview review;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف التقييم'),
        content: const Text('متأكد إنك عايز تحذف تقييمك؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('حذف', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.palette.error)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref
          .read(reviewsControllerProvider(centerId).notifier)
          .delete(review.id);
      if (context.mounted) AppToast.showSuccess(context, 'تم حذف تقييمك');
    } catch (e) {
      if (context.mounted) AppToast.showError(context, failureOf(e).message);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert_rounded, color: context.palette.textTertiary),
      onSelected: (v) {
        if (v == 'edit') {
          context.push('$centerReviewFormPath/$centerId', extra: review);
        } else {
          _delete(context, ref);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'edit', child: Text('تعديل')),
        PopupMenuItem(value: 'delete', child: Text('حذف')),
      ],
    );
  }
}

/// Home-screen ratings block: average + count + distribution, the latest 3
/// comments, "see all", and the add/edit CTA for the student's own review.
class CenterReviewsSection extends ConsumerWidget {
  const CenterReviewsSection({
    super.key,
    required this.centerId,
    this.fallbackRating = 0,
  });

  final int centerId;

  /// The center's own `rating` — used when the reviews endpoint doesn't
  /// send an average.
  final double fallbackRating;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewsControllerProvider(centerId));
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'التقييمات',
            onSeeAll: (async.valueOrNull?.items.isNotEmpty ?? false)
                ? () => context.push('$centerReviewsPath/$centerId')
                : null,
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          ),
          async.when(
            loading: () => const AppShimmer(
              child: Column(
                children: [
                  ShimmerCard(thumbnailSize: 40),
                  SizedBox(height: AppSpacing.listItemSpacing),
                  ShimmerCard(thumbnailSize: 40),
                ],
              ),
            ),
            error: (e, _) => AppCard(
              child: Column(
                children: [
                  Text(
                    'تعذر تحميل التقييمات',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton.text(
                    'إعادة المحاولة',
                    onPressed: () =>
                        ref.invalidate(reviewsControllerProvider(centerId)),
                  ),
                ],
              ),
            ),
            data: (state) => _Content(
              centerId: centerId,
              state: state,
              fallbackRating: fallbackRating,
            ),
          ),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.centerId,
    required this.state,
    required this.fallbackRating,
  });

  final int centerId;
  final ReviewsState state;
  final double fallbackRating;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    final count = state.summary?.count ?? state.total ?? items.length;
    final computed = items.isEmpty
        ? 0.0
        : items.fold<int>(0, (a, r) => a + r.rating) / items.length;
    final average =
        state.summary?.average ??
        (fallbackRating > 0 ? fallbackRating : computed);
    final mine = state.mine;
    final latest = items.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(
          average: average,
          count: count,
          distribution: state.summary?.distribution,
        ),
        const SizedBox(height: AppSpacing.md),
        if (mine == null)
          AppButton.primary(
            'أضف تقييمك',
            icon: Icons.star_rounded,
            onPressed: () => context.push('$centerReviewFormPath/$centerId'),
          )
        else ...[
          const _Label('تقييمك'),
          ReviewCard(
            review: mine,
            trailing: OwnReviewMenu(centerId: centerId, review: mine),
          ),
        ],
        if (latest.where((r) => !r.isOwner).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.base),
          const _Label('آخر التعليقات'),
          for (final r in latest.where((r) => !r.isOwner))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ReviewCard(review: r),
            ),
        ] else if (items.isEmpty)
          const EmptyState(
            message: 'لا توجد تقييمات بعد — كن أول من يقيّم',
            verticalPadding: AppSpacing.md,
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: context.palette.textSecondary,
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.average,
    required this.count,
    required this.distribution,
  });

  final double average;
  final int count;
  final Map<int, int>? distribution;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dist = distribution;
    final total = dist == null ? 0 : dist.values.fold<int>(0, (a, b) => a + b);

    return AppCard(
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                average.toStringAsFixed(1),
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 40,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              StarRow(rating: average, size: 16),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$count تقييم',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.textSecondary),
              ),
            ],
          ),
          if (dist != null && total > 0) ...[
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                children: [
                  for (var star = 5; star >= 1; star--)
                    _DistributionBar(
                      star: star,
                      fraction: (dist[star] ?? 0) / total,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DistributionBar extends StatelessWidget {
  const _DistributionBar({required this.star, required this.fraction});

  final int star;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Row(
              children: [
                Text(
                  '$star',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                ),
                Icon(
                  Icons.star_rounded,
                  size: 12,
                  color: context.palette.gold,
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.xs),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: palette.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(context.palette.gold),
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '${(fraction * 100).round()}%',
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
