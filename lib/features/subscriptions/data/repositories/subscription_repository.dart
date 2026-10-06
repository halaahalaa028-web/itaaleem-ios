import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/subjects/data/datasources/subjects_remote_data_source.dart';
import 'package:itaaleem/features/subscriptions/data/models/subject_subscription_model.dart';

/// Subject subscriptions. The server endpoints are new (see
/// `docs/api/subject_subscriptions_routes.md`); until they're deployed every
/// call degrades gracefully: a 404 means "feature not on this server" and
/// leaves every subject open, without re-asking for each subject.
class SubscriptionRepository {
  SubscriptionRepository(this._dio, this._subjects);

  final Dio _dio;
  final SubjectsRemoteDataSource _subjects;

  /// Set after the first 404 — later lookups skip the network entirely.
  static bool _endpointMissing = false;

  /// Lets the next lookup ask the server again (pull-to-refresh).
  static void resetEndpointCheck() => _endpointMissing = false;

  Future<SubjectSubscriptionStatus> getSubjectStatus(int subjectId) async {
    if (_endpointMissing) return const SubjectSubscriptionStatus.open();
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.subjectSubscriptionStatus(subjectId),
      );
      return SubjectSubscriptionStatus.fromJson(response.data ?? const {});
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        _endpointMissing = true;
        if (kDebugMode) {
          debugPrint('[Subscriptions] status endpoint missing — subjects open');
        }
        return const SubjectSubscriptionStatus.open();
      }
      rethrow;
    }
  }

  /// `[]` when the endpoint isn't deployed yet.
  Future<List<SubjectSubscription>> getMySubscriptions() async {
    try {
      final response = await _dio.get<dynamic>(ApiEndpoints.mySubscriptions);
      final body = response.data;
      if (kDebugMode) {
        debugPrint('>>> GET ${ApiEndpoints.mySubscriptions}: $body');
      }
      final raw = _listIn(body);
      return raw
          .whereType<Map>()
          .map(
            (e) => SubjectSubscription.fromJson(Map<String, dynamic>.from(e)),
          )
          .toList();
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '>>> GET ${ApiEndpoints.mySubscriptions} FAILED: '
          '${e.response?.statusCode} ${e.response?.data ?? e.message}',
        );
      }
      if (e.response?.statusCode == 404 || e.response?.statusCode == 405) {
        return const [];
      }
      rethrow;
    }
  }

  /// The subscriptions list inside any of the envelopes this API uses: a
  /// bare list, `{data: [...]}`, `{data: {items: [...]}}`, a Laravel
  /// paginator `{data: {data: [...]}}`, or `subscriptions` at either level.
  static List<dynamic> _listIn(Object? body, [int depth = 0]) {
    if (body is List) return body;
    if (body is! Map || depth > 3) return const [];
    for (final key in ['items', 'subscriptions', 'data']) {
      final value = body[key];
      if (value is List) return value;
    }
    for (final key in ['data', 'subscriptions']) {
      final value = body[key];
      if (value is Map) return _listIn(value, depth + 1);
    }
    return const [];
  }

  /// Asks the center to activate [subjectId]. Goes through the existing
  /// `POST /subscription-requests` (already live and handled by the admins),
  /// so it works today without the new endpoints.
  Future<void> requestSubscription(int subjectId) =>
      _subjects.requestSubscription(subjectId: subjectId);
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(
    ref.watch(dioClientProvider),
    ref.watch(subjectsRemoteDataSourceProvider),
  );
});
