import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/teachers/data/models/teacher_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `GET /teachers` — the joined center's teachers, distinct from the
/// course-scoped `GET /public/teachers` [CoursesRemoteDataSource] already
/// calls.
class TeachersRemoteDataSource {
  TeachersRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<TeacherModel>> getTeachers() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.teachers,
    );
    if (kDebugMode) {
      debugPrint('>>> GET ${ApiEndpoints.teachers} raw response: ${response.data}');
    }
    final body = response.data;
    final envelope = body?['data'];
    final rawList = (body?['teachers'] is List ? body!['teachers'] as List : null) ??
        (envelope is List ? envelope : null) ??
        (envelope is Map<String, dynamic> && envelope['items'] is List
            ? envelope['items'] as List
            : null) ??
        const [];
    return rawList
        .map((e) => TeacherModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final teachersRemoteDataSourceProvider = Provider<TeachersRemoteDataSource>((
  ref,
) {
  final dio = ref.watch(dioClientProvider);
  return TeachersRemoteDataSource(dio);
});
