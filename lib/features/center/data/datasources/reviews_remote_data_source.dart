import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/center/data/models/center_review.dart';

/// Raw Dio calls against `/centers/{id}/reviews`. Tolerant of the response
/// envelope (`{data: {items, meta}}`, `{data: [...]}` or bare `{items}`),
/// like the other `/centers` calls.
class ReviewsRemoteDataSource {
  ReviewsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<ReviewsPage> fetchReviews(
    int centerId, {
    int page = 1,
    int perPage = 10,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.centerReviews(centerId),
      queryParameters: {'page': page, 'per_page': perPage},
    );
    final body = response.data ?? const <String, dynamic>{};
    final data = body['data'];
    final root = data is Map<String, dynamic> ? data : body;

    final rawList = data is List
        ? data
        : (root['items'] ?? root['reviews'] ?? root['data']);
    final items = <CenterReview>[
      if (rawList is List)
        for (final e in rawList)
          if (e is Map<String, dynamic>) CenterReview.fromJson(e),
    ];

    final metaRaw = root['meta'] ?? body['meta'];
    final meta = metaRaw is Map<String, dynamic> ? metaRaw : const {};
    int? metaInt(String k) {
      final v = meta[k] ?? root[k];
      return v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    }

    final summaryRaw = root['summary'] ?? body['summary'] ?? root['stats'];
    final mineRaw = root['my_review'] ?? body['my_review'];
    return ReviewsPage(
      items: items,
      currentPage: metaInt('current_page') ?? page,
      lastPage: metaInt('last_page') ?? page,
      total: metaInt('total'),
      summary: ReviewsSummary.fromJson(
        summaryRaw is Map<String, dynamic> ? summaryRaw : root,
      ),
      mine: mineRaw is Map<String, dynamic>
          ? CenterReview.fromJson({...mineRaw, 'is_owner': true})
          : null,
    );
  }

  Future<void> submitReview(
    int centerId, {
    required int rating,
    required String comment,
  }) async {
    await _dio.post<Object?>(
      ApiEndpoints.centerReviews(centerId),
      data: {'rating': rating, 'comment': comment},
    );
  }

  Future<void> updateReview(
    int centerId,
    int reviewId, {
    required int rating,
    required String comment,
  }) async {
    await _dio.put<Object?>(
      ApiEndpoints.centerReview(centerId, reviewId),
      data: {'rating': rating, 'comment': comment},
    );
  }

  Future<void> deleteReview(int centerId, int reviewId) async {
    await _dio.delete<Object?>(ApiEndpoints.centerReview(centerId, reviewId));
  }
}

final reviewsRemoteDataSourceProvider = Provider<ReviewsRemoteDataSource>((
  ref,
) {
  return ReviewsRemoteDataSource(ref.watch(dioClientProvider));
});
