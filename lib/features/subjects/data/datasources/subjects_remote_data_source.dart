import 'dart:convert';

import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/subjects/data/models/subject_json_mapper.dart';
import 'package:itaaleem/features/subjects/domain/entities/subject.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Raw Dio calls against `/subjects` and `/lessons` — not documented in
/// APP_SPEC.md, verified live against the backend directly.
class SubjectsRemoteDataSource {
  SubjectsRemoteDataSource(this._dio);

  final Dio _dio;

  Future<List<Subject>> getSubjects() async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(ApiEndpoints.subjects);
    } on DioException catch (e) {
      // No connection — show the last list this student loaded, if any.
      final cached = await SubjectsCache.load('subjects');
      if (SubjectsCache.isConnectionError(e) && cached is List) {
        return cached
            .map((e) => subjectFromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
    if (kDebugMode) {
      debugPrint(
        '>>> GET ${ApiEndpoints.subjects} raw response: ${response.data}',
      );
    }
    final rawList = _extractList(response.data, 'subjects');
    await SubjectsCache.save('subjects', rawList);
    return rawList
        .map((e) => subjectFromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Subject> getSubjectDetails(int id) async {
    final Response<Map<String, dynamic>> response;
    try {
      response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.subjectDetails(id),
      );
    } on DioException catch (e) {
      final cached = await SubjectsCache.load('subject_$id');
      if (SubjectsCache.isConnectionError(e) &&
          cached is Map<String, dynamic>) {
        return subjectFromJson(cached);
      }
      rethrow;
    }
    if (kDebugMode) {
      debugPrint(
        '>>> GET ${ApiEndpoints.subjectDetails(id)} raw response: ${response.data}',
      );
    }
    final envelope = response.data?['data'] ?? response.data?['subject'];
    final body = envelope is Map<String, dynamic>
        ? envelope
        : (response.data ?? const <String, dynamic>{});
    await SubjectsCache.save('subject_$id', body);
    return subjectFromJson(body);
  }

  Future<List<SubjectLesson>> getLessons({
    required int subjectId,
    int? limit,
  }) async {
    if (kDebugMode) {
      debugPrint('>>> GET lessons for subject $subjectId');
    }
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.lessons,
      queryParameters: {
        'subject_id': subjectId,
        if (limit != null) 'limit': limit,
      },
    );
    if (kDebugMode) {
      debugPrint('>>> lessons response: ${response.data}');
    }
    final rawList = _extractList(response.data, 'lessons');
    return rawList
        .map((e) => subjectLessonFromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// `POST /subscription-requests` — throws a [DioException] on failure.
  Future<void> requestSubscription({int? subjectId, int? lessonId}) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.subscriptionRequests,
      data: {
        if (subjectId != null) 'subject_id': subjectId,
        if (lessonId != null) 'lesson_id': lessonId,
      },
    );
    if (kDebugMode) {
      debugPrint(
        '>>> POST subscription-requests: ${response.statusCode} ${response.data}',
      );
    }
  }

  /// `GET /attachments?subject_id=` — a subject's downloadable files.
  ///
  /// With [lessonId], also sends `lesson_id=` and drops any file the API
  /// explicitly ties to a *different* lesson (files with no lesson link are
  /// kept, since the backend may not scope by lesson at all).
  Future<List<SubjectAttachment>> getAttachments(
    int subjectId, {
    int? lessonId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.attachments,
      queryParameters: {
        'subject_id': subjectId,
        if (lessonId != null) 'lesson_id': lessonId,
      },
    );
    if (kDebugMode) {
      debugPrint('>>> attachments for subject $subjectId: ${response.data}');
    }
    final rawList = _extractList(response.data, 'attachments');
    return rawList
        .map((e) => subjectAttachmentFromJson(e as Map<String, dynamic>))
        .where(
          (a) =>
              lessonId == null || a.lessonId == null || a.lessonId == lessonId,
        )
        .toList();
  }
}

/// Last successful `GET /subjects` / `GET /subjects/{id}` bodies, so a
/// logged-in student without internet still sees their subjects (and the
/// lessons they can play from "التنزيلات"). Cleared on logout — it belongs to
/// whoever was signed in.
class SubjectsCache {
  SubjectsCache._();

  static const _prefix = 'subjects_cache_v1_';

  static Future<void> save(String key, Object value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefix$key', jsonEncode(value));
    } catch (_) {
      // Best effort — a failed cache write must never break a live load.
    }
  }

  static Future<Object?> load(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_prefix$key');
      return raw == null ? null : jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs.getKeys().where((k) => k.startsWith(_prefix)).toList()) {
      await prefs.remove(key);
    }
  }

  static bool isConnectionError(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.sendTimeout ||
      e.type == DioExceptionType.receiveTimeout ||
      (e.type == DioExceptionType.unknown && e.response == null);
}

/// Pulls a list out of a JSON response body that may wrap it under `data`
/// (`{"data": [...]}` or the paginated `{"data": {"items": [...]}}`), or
/// bare under [key] (`{"<key>": [...]}` — confirmed live for `GET
/// /centers?code=`, which returns `{"centers": [...]}` with no `data`
/// envelope at all). Tries every shape rather than assuming one, so a
/// response actually using the bare-key shape doesn't silently look like an
/// empty list.
List<dynamic> _extractList(Map<String, dynamic>? body, String key) {
  final envelope = body?['data'];
  return _asList(body?[key]) ??
      _asList(envelope) ??
      _asList(envelope is Map<String, dynamic> ? envelope['items'] : null) ??
      const [];
}

List<dynamic>? _asList(Object? value) => value is List ? value : null;

final subjectsRemoteDataSourceProvider = Provider<SubjectsRemoteDataSource>((
  ref,
) {
  final dio = ref.watch(dioClientProvider);
  return SubjectsRemoteDataSource(dio);
});
