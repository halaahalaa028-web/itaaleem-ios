import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_api.dart';
import 'package:itaaleem/features/center_admin/data/center_admin_models.dart';

/// Turns `/center-admin/*` JSON into [AdminRecord]s and every error into a
/// [Failure] with an Arabic message the screens show as-is.
class CenterAdminRepository {
  CenterAdminRepository(this._api);

  final CenterAdminApi _api;

  static const perPage = 20;

  Future<CenterDashboardData> getDashboard() => _guard(() async {
    final body = await _api.get('dashboard');
    final data = extractAdminObject(body);
    // Counters may sit at the root, under `stats`, or under `counts`.
    final merged = <String, dynamic>{
      ...data,
      for (final key in const ['stats', 'counts', 'statistics'])
        if (data[key] is Map) ...Map<String, dynamic>.from(data[key] as Map),
    };
    if (kDebugMode) {
      debugPrint('>>> center-admin dashboard keys: ${merged.keys}');
    }
    // Anything the dashboard doesn't count is counted from its own list.
    await Future.wait([
      for (final (key, path) in _countedSections)
        if (AdminRecord(merged).number([key, ..._aliases(key)]) == null)
          _countOf(path).then((n) {
            if (n != null) merged[key] = n;
          }),
    ]);
    final stats = AdminRecord(merged);
    final center = data['center'] is Map
        ? AdminRecord(Map<String, dynamic>.from(data['center'] as Map))
        : null;
    List<AdminRecord> listOf(List<String> keys) {
      for (final key in keys) {
        final value = data[key];
        if (value is List) {
          return [
            for (final e in value)
              if (e is Map) AdminRecord(Map<String, dynamic>.from(e)),
          ];
        }
      }
      return const [];
    }

    return CenterDashboardData(
      stats: stats,
      recentSubscriptions: listOf([
        'recent_subscriptions',
        'latest_subscriptions',
      ]).take(5).toList(),
      recentStudents: listOf([
        'recent_students',
        'latest_students',
      ]).take(5).toList(),
      centerName: center?.title,
      centerLogo: center?.image,
    );
  });

  static const _countedSections = [
    ('subjects_count', 'subjects'),
    ('teachers_count', 'teachers'),
    ('lectures_count', 'lectures'),
    ('exams_count', 'exams'),
    ('files_count', 'files'),
  ];

  /// Other spellings of `<x>_count` the server may use.
  static List<String> _aliases(String key) {
    final base = key.replaceAll('_count', '');
    return [base, 'total_$base', '${base}_total'];
  }

  /// A section's total: the paginator's `total` when present, else the
  /// length of its (unpaginated) list. `null` if the call fails.
  Future<int?> _countOf(String path) async {
    try {
      final body = await _api.get(path, query: {'per_page': 1});
      int? i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
      if (body is Map) {
        final data = body['data'];
        for (final m in [
          body,
          body['meta'],
          body['pagination'],
          data,
          if (data is Map) data['meta'],
          if (data is Map) data['pagination'],
        ]) {
          if (m is Map && i(m['total']) != null) return i(m['total']);
        }
      }
      final list = extractAdminList(body);
      // Without a paginator total the server ignored per_page → full list.
      return list.length;
    } catch (e) {
      if (kDebugMode) debugPrint('>>> center-admin count of $path failed: $e');
      return null;
    }
  }

  /// A page of any list section (`students`, `subjects`, …).
  Future<AdminPageResult> getPage(
    String path, {
    int page = 1,
    String? search,
    Map<String, dynamic> filters = const {},
  }) => _guard(() async {
    final body = await _api.get(
      path,
      query: {
        'page': page,
        'per_page': perPage,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        ...filters,
      },
    );
    final items = [
      for (final e in extractAdminList(body))
        if (e is Map) AdminRecord(Map<String, dynamic>.from(e)),
    ];
    final paging = extractAdminPaging(body, page, items.length, perPage);
    return AdminPageResult(
      items: items,
      page: paging.page,
      hasMore: paging.hasMore,
    );
  });

  /// One object (`students/5`, `stats`, `settings`).
  Future<AdminRecord> getOne(String path) => _guard(() async {
    return AdminRecord(extractAdminObject(await _api.get(path)));
  });

  Future<void> create(String path, Map<String, dynamic> data) =>
      _guard(() => _api.post(path, data));

  Future<void> update(String path, Map<String, dynamic> data) =>
      _guard(() => _api.put(path, data));

  Future<void> action(String path, [Map<String, dynamic>? data]) =>
      _guard(() => _api.post(path, data));

  Future<void> remove(String path) => _guard(() => _api.delete(path));

  // --- Subscription requests ---------------------------------------------

  /// Pending subscription requests (`GET subscriptions?status=pending`) —
  /// newest first — plus the total (paginator `total`, else the count).
  Future<({List<AdminRecord> items, int total})> pendingRequests({
    int limit = 50,
  }) => _guard(() async {
    final body = await _api.get(
      'subscriptions',
      query: {'status': 'pending', 'per_page': limit},
    );
    final items =
        [
          for (final e in extractAdminList(body))
            if (e is Map) AdminRecord(Map<String, dynamic>.from(e)),
        ]..sort((a, b) {
          final da = a.date(['created_at', 'requested_at']);
          final db = b.date(['created_at', 'requested_at']);
          if (da == null || db == null) return 0;
          return db.compareTo(da);
        });
    return (items: items, total: _totalOf(body) ?? items.length);
  });

  /// Activates a pending request for [subjectIds].
  ///
  /// `POST subscriptions/{id}/approve` `{subject_ids}` when the server has it.
  /// It currently doesn't (404), so the fallback uses the routes that exist:
  /// `PUT subscriptions/{id}` activates the request itself (first subject),
  /// and `POST subscriptions` adds one active subscription per extra subject.
  Future<void> approveRequest(
    AdminRecord request,
    List<int> subjectIds, {
    int durationDays = 30,
  }) => _guard(() async {
    final id = request.id;
    try {
      await _api.post('subscriptions/$id/approve', {
        'subject_ids': subjectIds,
        'duration_days': durationDays,
      });
      return;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code != 404 && code != 405) rethrow;
      if (kDebugMode) {
        debugPrint('>>> approve route missing ($code) — using PUT fallback');
      }
    }
    final studentId = request.nestedId('student');
    final requested = request.nestedId('subject');
    final first = subjectIds.contains(requested)
        ? requested!
        : subjectIds.first;
    await _api.put('subscriptions/$id', {
      'status': 'active',
      'subject_id': first,
      'subject_ids': subjectIds,
      'duration_days': durationDays,
    });
    for (final subjectId in subjectIds.where((s) => s != first)) {
      await _api.post('subscriptions', {
        'student_id': ?studentId,
        'subject_id': subjectId,
        'status': 'active',
        'duration_days': durationDays,
      });
    }
  });

  // --- Lectures --------------------------------------------------------------

  /// Every lecture of the center, grouped by subject. `GET lectures` answers
  /// 405 on the live server, so lectures come from each subject's
  /// `GET subjects/{id}/lectures` (in parallel); `GET lectures` is still
  /// tried first in case it gets a GET handler.
  Future<List<({AdminRecord subject, List<AdminRecord> lectures})>>
  lecturesBySubject() => _guard(() async {
    final subjects = [
      for (final e in extractAdminList(
        await _api.get('subjects', query: {'per_page': 100}),
      ))
        if (e is Map) AdminRecord(Map<String, dynamic>.from(e)),
    ];
    List<AdminRecord> recordsOf(Object? body) => [
      for (final e in extractAdminList(body))
        if (e is Map) AdminRecord(Map<String, dynamic>.from(e)),
    ];

    // Preferred: one call, grouped client-side.
    try {
      final all = recordsOf(
        await _api.get('lectures', query: {'per_page': 500}),
      );
      if (all.isNotEmpty) {
        final byId = {for (final s in subjects) s.id: <AdminRecord>[]};
        final orphans = <AdminRecord>[];
        for (final l in all) {
          (byId[l.nestedId('subject')] ?? orphans).add(l);
        }
        return [
          for (final s in subjects)
            if (byId[s.id]!.isNotEmpty) (subject: s, lectures: byId[s.id]!),
          if (orphans.isNotEmpty)
            (
              subject: const AdminRecord({'name': 'بدون مادة'}),
              lectures: orphans,
            ),
        ];
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          '>>> GET lectures ${e.response?.statusCode} — per subject instead',
        );
      }
    }

    final lists = await Future.wait([
      for (final s in subjects)
        _api
            .get('subjects/${s.id}/lectures', query: {'per_page': 200})
            .then(recordsOf)
            .catchError((Object _) => <AdminRecord>[]),
    ]);
    return [
      for (var i = 0; i < subjects.length; i++)
        (subject: subjects[i], lectures: lists[i]),
    ];
  });

  // --- Activation codes -------------------------------------------------------

  /// `GET activation-codes` — not on the server yet (404 → "غير متاح").
  Future<List<AdminRecord>> activationCodes() => _guard(() async {
    return [
      for (final e in extractAdminList(await _api.get('activation-codes')))
        if (e is Map) AdminRecord(Map<String, dynamic>.from(e)),
    ];
  });

  /// `POST activation-codes` `{subject_ids, duration_months}` — returns the
  /// created code record (its `code` text).
  Future<AdminRecord> createActivationCode({
    required List<int> subjectIds,
    required int durationMonths,
  }) => _guard(() async {
    final body = await _api.post('activation-codes', {
      'subject_ids': subjectIds,
      'duration_months': durationMonths,
    });
    return AdminRecord(extractAdminObject(body));
  });

  static int? _totalOf(Object? body) {
    int? i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');
    if (body is! Map) return null;
    final data = body['data'];
    for (final m in [
      body,
      body['meta'],
      body['pagination'],
      data,
      if (data is Map) data['meta'],
    ]) {
      if (m is Map && i(m['total']) != null) return i(m['total']);
    }
    return null;
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw _failureOf(e);
    }
  }

  static Failure _failureOf(DioException e) {
    final status = e.response?.statusCode;
    final serverMessage = _serverMessage(e.response?.data);
    switch (status) {
      case 401:
        return const UnauthorizedFailure('انتهت الجلسة، سجّل الدخول مرة أخرى');
      case 403:
        return const ServerFailure(
          'ليس لديك صلاحية مدير السنتر لهذا القسم',
          statusCode: 403,
        );
      case 404:
      case 405:
      case 501:
        return ServerFailure(
          'هذا القسم غير متاح على السيرفر حالياً',
          statusCode: status,
        );
      case 422:
        return ValidationFailure(serverMessage ?? 'البيانات المدخلة غير صحيحة');
    }
    if (status != null && status >= 500) {
      return ServerFailure(
        'حصلت مشكلة في السيرفر، جرّب تاني بعد شوية',
        statusCode: status,
      );
    }
    final mapped = failureOf(e);
    if (mapped is! UnknownFailure) return mapped;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const NetworkFailure('تأكد من الاتصال بالإنترنت');
    }
    return ServerFailure(serverMessage ?? 'حدث خطأ، حاول مرة أخرى');
  }

  static String? _serverMessage(Object? body) {
    if (body is! Map) return null;
    final message = body['message'];
    if (message is String && message.trim().isNotEmpty) return message;
    final errors = body['errors'];
    if (errors is Map && errors.isNotEmpty) {
      final first = errors.values.first;
      if (first is List && first.isNotEmpty) return '${first.first}';
      return '$first';
    }
    return null;
  }
}

final centerAdminRepositoryProvider = Provider<CenterAdminRepository>(
  (ref) => CenterAdminRepository(ref.watch(centerAdminApiProvider)),
);
