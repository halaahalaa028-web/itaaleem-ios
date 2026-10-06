import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/features/center/data/datasources/reviews_remote_data_source.dart';
import 'package:itaaleem/features/center/data/models/center_review.dart';

class ReviewsState {
  const ReviewsState({
    required this.items,
    required this.page,
    required this.hasMore,
    required this.summary,
    required this.total,
    this.loadingMore = false,
  });

  final List<CenterReview> items;
  final int page;
  final bool hasMore;
  final ReviewsSummary? summary;
  final int? total;
  final bool loadingMore;

  /// The signed-in student's own review, if it's in what's been loaded.
  CenterReview? get mine {
    for (final r in items) {
      if (r.isOwner) return r;
    }
    return null;
  }

  ReviewsState copyWith({
    List<CenterReview>? items,
    int? page,
    bool? hasMore,
    bool? loadingMore,
  }) => ReviewsState(
    items: items ?? this.items,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    summary: summary,
    total: total,
    loadingMore: loadingMore ?? this.loadingMore,
  );
}

/// Shared by the home section and the full reviews screen (same provider
/// instance per center), so a submit/edit/delete shows up in both at once.
class ReviewsController
    extends AutoDisposeFamilyAsyncNotifier<ReviewsState, int> {
  static const _perPage = 10;

  ReviewsRemoteDataSource get _api => ref.read(reviewsRemoteDataSourceProvider);

  @override
  Future<ReviewsState> build(int arg) => _loadFirstPage();

  Future<ReviewsState> _loadFirstPage() async {
    final page = await _api.fetchReviews(arg, perPage: _perPage);
    final items = [...page.items];
    // A separately-sent `my_review` may not be inside the first page.
    if (page.mine != null && !items.any((r) => r.id == page.mine!.id)) {
      items.insert(0, page.mine!);
    }
    return ReviewsState(
      items: items,
      page: page.currentPage,
      hasMore: page.hasMore,
      summary: page.summary,
      total: page.total,
    );
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.loadingMore || !current.hasMore) return;
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final next = await _api.fetchReviews(
        arg,
        page: current.page + 1,
        perPage: _perPage,
      );
      final known = current.items.map((r) => r.id).toSet();
      state = AsyncData(
        current.copyWith(
          items: [
            ...current.items,
            ...next.items.where((r) => !known.contains(r.id)),
          ],
          page: next.currentPage,
          hasMore: next.hasMore,
          loadingMore: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(loadingMore: false));
    }
  }

  /// Re-fetches page 1 in place (no loading flash) after a write.
  Future<void> _reload() async {
    state = await AsyncValue.guard(_loadFirstPage);
  }

  /// Each of these throws on failure so the caller can show the error.
  Future<void> submit(int rating, String comment) async {
    await _api.submitReview(arg, rating: rating, comment: comment);
    await _reload();
  }

  Future<void> updateReview(int reviewId, int rating, String comment) async {
    await _api.updateReview(arg, reviewId, rating: rating, comment: comment);
    await _reload();
  }

  Future<void> delete(int reviewId) async {
    await _api.deleteReview(arg, reviewId);
    await _reload();
  }
}

final reviewsControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ReviewsController, ReviewsState, int>(ReviewsController.new);
