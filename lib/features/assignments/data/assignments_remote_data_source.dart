import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/assignments/domain/entities/assignment.dart';

/// Raw Dio calls for the assignments endpoints. Errors surface as
/// [DioException]s carrying a `Failure` (see `failureOf`).
class AssignmentsRemoteDataSource {
  AssignmentsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Assignment>> getForSubject(int subjectId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.subjectAssignments(subjectId),
      );
      final items = <Assignment>[];
      for (final raw in _list(response.data)) {
        if (raw is! Map<String, dynamic>) continue;
        try {
          items.add(Assignment.fromJson(raw));
        } catch (e) {
          if (kDebugMode) debugPrint('[assignments] skipped bad item: $e');
        }
      }
      return items;
    } on DioException catch (e) {
      // No assignments for the subject (404) or a backend 5xx on this
      // endpoint shows the empty state instead of a dead-end error.
      final code = e.response?.statusCode;
      if (kDebugMode) {
        debugPrint(
          '[assignments] GET ${ApiEndpoints.subjectAssignments(subjectId)} '
          'failed ($code): ${e.response?.data}',
        );
      }
      if (code == 404 || (code != null && code >= 500)) return const [];
      rethrow;
    }
  }

  Future<Assignment> getDetails(int id) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.assignmentDetails(id),
    );
    return Assignment.fromJson(_map(response.data));
  }

  /// `null` when the student hasn't submitted yet (404).
  Future<AssignmentSubmission?> getSubmission(int id) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.assignmentSubmission(id),
      );
      final body = _map(response.data);
      if (body.isEmpty) return null;
      return AssignmentSubmission.fromJson(body);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> submit(int id, {required String filePath, String? notes}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.assignmentSubmit(id),
      data: form,
    );
  }
}

List<dynamic> _list(Map<String, dynamic>? body) {
  final data = body?['data'];
  if (data is List) return data;
  if (data is Map<String, dynamic>) {
    final items = data['items'] ?? data['assignments'] ?? data['data'];
    if (items is List) return items;
  }
  final bare = body?['assignments'];
  return bare is List ? bare : const [];
}

Map<String, dynamic> _map(Map<String, dynamic>? body) {
  final data = body?['data'];
  return data is Map<String, dynamic> ? data : (body ?? const {});
}

final assignmentsRemoteDataSourceProvider =
    Provider<AssignmentsRemoteDataSource>((ref) {
      return AssignmentsRemoteDataSource(ref.watch(dioClientProvider));
    });
