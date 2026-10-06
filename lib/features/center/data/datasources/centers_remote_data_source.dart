import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/center/data/models/center_json_mapper.dart';
import 'package:itaaleem/features/center/domain/entities/center_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Raw Dio calls against the `/centers` endpoints — not documented in
/// APP_SPEC.md, but confirmed live against the backend directly (paginated
/// `{items, meta}` list, detail with `grades`, join/leave by grade).
class CentersRemoteDataSource {
  CentersRemoteDataSource(this._dio);

  final Dio _dio;

  /// `GET /centers?code=` — the center matching this exact code, or `null`
  /// when there isn't one.
  ///
  /// The live response for this endpoint is a bare `{"centers": [...]}` —
  /// not the `{"data": {"items": [...]}}` envelope [getCenterDetails] and
  /// the rest of this class's calls use — so `centers` is tried first, with
  /// the usual `data`/`data.items` shapes kept as fallbacks in case that
  /// ever changes.
  Future<CenterModel?> getCenterByCode(String code) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.centers,
      queryParameters: {'code': code},
    );
    if (kDebugMode) {
      debugPrint('Search URL: ${response.requestOptions.uri}');
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.data}');
    }
    final body = response.data;
    final data = body?['data'];
    final rawList = _asList(body?['centers']) ??
        _asList(data) ??
        _asList(data is Map<String, dynamic> ? data['items'] : null) ??
        const [];
    if (rawList.isEmpty) return null;
    return centerModelFromJson(rawList.first as Map<String, dynamic>);
  }

  static List<dynamic>? _asList(Object? value) => value is List ? value : null;

  Future<CenterModel> getCenterDetails(int id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.centerDetails(id),
    );
    if (kDebugMode) {
      debugPrint(
        '>>> GET ${ApiEndpoints.centerDetails(id)} raw response: ${response.data}',
      );
    }
    final data = response.data?['data'];
    final body = data is Map<String, dynamic> ? data : (response.data ?? const <String, dynamic>{});
    return centerModelFromJson(body);
  }

  /// Joins (or, re-confirmed with a different grade, upserts) the center
  /// membership, by [code] — the backend resolves the center from its
  /// `code`, not from an id in the URL. [gradeId] is omitted for centers
  /// with no grades to choose from. Throws [DioException] on failure — the
  /// caller decides how to surface it.
  Future<void> joinCenter({required String code, int? gradeId}) async {
    if (kDebugMode) {
      debugPrint('>>> POST ${ApiEndpoints.centerJoin} code=$code grade_id=$gradeId');
    }
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.centerJoin,
      data: {
        'code': code,
        if (gradeId != null) 'grade_id': gradeId,
      },
    );
  }

  Future<void> leaveCenter() async {
    await _dio.post<Map<String, dynamic>>(ApiEndpoints.centersLeave);
  }
}

final centersRemoteDataSourceProvider = Provider<CentersRemoteDataSource>((ref) {
  final dio = ref.watch(dioClientProvider);
  return CentersRemoteDataSource(dio);
});
