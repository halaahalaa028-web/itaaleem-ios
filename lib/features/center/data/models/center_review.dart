/// One student review of a center (`/centers/{id}/reviews`).
class CenterReview {
  const CenterReview({
    required this.id,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.studentName,
    this.studentAvatar,
    this.isOwner = false,
  });

  final int id;
  final int rating;
  final String comment;
  final DateTime? createdAt;
  final String studentName;
  final String? studentAvatar;

  /// `true` when the signed-in student wrote this review.
  final bool isOwner;

  factory CenterReview.fromJson(Map<String, dynamic> json) {
    final student = json['student'] ?? json['user'];
    final studentMap = student is Map<String, dynamic> ? student : null;
    String? str(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return CenterReview(
      id: _int(json['id']) ?? 0,
      rating: (_int(json['rating']) ?? 0).clamp(0, 5),
      comment: str(json['comment']) ?? '',
      createdAt: DateTime.tryParse(str(json['created_at']) ?? ''),
      studentName:
          str(json['student_name']) ??
          str(studentMap?['full_name']) ??
          str(studentMap?['name']) ??
          'طالب',
      studentAvatar:
          str(json['student_avatar']) ??
          str(studentMap?['avatar']) ??
          str(studentMap?['avatar_url']),
      isOwner: json['is_owner'] == true || json['is_owner'] == 1,
    );
  }
}

/// Aggregate numbers for the ratings header. Any field the backend doesn't
/// send stays `null` and the UI hides or falls back accordingly.
class ReviewsSummary {
  const ReviewsSummary({this.average, this.count, this.distribution});

  final double? average;
  final int? count;

  /// Star (1..5) → number of reviews.
  final Map<int, int>? distribution;

  static ReviewsSummary fromJson(Map<String, dynamic> json) {
    Map<int, int>? dist;
    final raw =
        json['distribution'] ??
        json['ratings_distribution'] ??
        json['rating_distribution'] ??
        json['breakdown'];
    if (raw is Map) {
      dist = {
        for (final e in raw.entries)
          if (int.tryParse('${e.key}') != null && _int(e.value) != null)
            int.parse('${e.key}'): _int(e.value)!,
      };
      if (dist.isEmpty) dist = null;
    }
    return ReviewsSummary(
      average: _double(
        json['average_rating'] ?? json['avg_rating'] ?? json['average'],
      ),
      count: _int(
        json['total_reviews'] ??
            json['reviews_count'] ??
            json['count'] ??
            json['total'],
      ),
      distribution: dist,
    );
  }
}

/// One page of `GET /centers/{id}/reviews`.
class ReviewsPage {
  const ReviewsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    this.summary,
    this.mine,
    this.total,
  });

  final List<CenterReview> items;
  final int currentPage;
  final int lastPage;
  final ReviewsSummary? summary;
  final CenterReview? mine;
  final int? total;

  bool get hasMore => currentPage < lastPage;
}

int? _int(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
double? _double(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
