import 'package:flutter/material.dart';
import 'package:itaaleem/core/widgets/app_shimmer.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/widgets/error_view.dart';
import 'package:itaaleem/features/center/presentation/providers/reviews_providers.dart';
import 'package:itaaleem/features/center/presentation/widgets/center_reviews_section.dart';
import 'package:itaaleem/features/center/presentation/widgets/review_widgets.dart';
import 'package:itaaleem/core/theme/app_spacing.dart';

/// Every review of a center, loaded page by page as the list nears its end.
class AllReviewsScreen extends ConsumerStatefulWidget {
  const AllReviewsScreen({super.key, required this.centerId});

  final int centerId;

  @override
  ConsumerState<AllReviewsScreen> createState() => _AllReviewsScreenState();
}

class _AllReviewsScreenState extends ConsumerState<AllReviewsScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) {
        ref
            .read(reviewsControllerProvider(widget.centerId).notifier)
            .loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(reviewsControllerProvider(widget.centerId));

    return Scaffold(
      appBar: AppBar(title: const Text('كل التقييمات')),
      body: async.when(
        loading: () => const ShimmerList(count: 4, thumbnailSize: 40),
        error: (e, _) => ErrorView(
          message: failureOf(e).message,
          retryLabel: 'إعادة المحاولة',
          onRetry: () =>
              ref.invalidate(reviewsControllerProvider(widget.centerId)),
        ),
        data: (state) {
          if (state.items.isEmpty) {
            return const Center(child: Text('لا توجد تقييمات بعد'));
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.refresh(reviewsControllerProvider(widget.centerId).future),
            child: ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.listItemSpacing),
              itemBuilder: (context, i) {
                if (i >= state.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final r = state.items[i];
                return KeyedSubtree(
                  key: ValueKey(r.id),
                  child: ReviewCard(
                    review: r,
                    trailing: r.isOwner
                        ? OwnReviewMenu(centerId: widget.centerId, review: r)
                        : null,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
