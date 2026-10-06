import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';

/// Thrown when an `/admin/*` route isn't deployed on the server yet — the
/// screens show it as a "coming soon" state rather than an error.
const adminEndpointMissing = ServerFailure(
  'هذه الخاصية غير متاحة على السيرفر بعد — استخدم لوحة التحكم الكاملة مؤقتاً',
  statusCode: 404,
);

bool isAdminEndpointMissing(Object error) =>
    identical(failureOf(error), adminEndpointMissing);

/// Center-admin API for the in-app dashboard (`docs/api/admin_routes.md`).
///
/// Every call throws a [Failure] (never a raw [DioException]) so screens can
/// show `failureOf(error).message` directly: 404/405/501 →
/// [adminEndpointMissing], 401/403 → a "no admin permission"
/// [ServerFailure], anything else → the interceptor's mapped failure.
class AdminRepository {
  AdminRepository(this._dio);

  final Dio _dio;

  // ── Dashboard Stats ──

  /// Never throws — the dashboard still renders its quick actions with
  /// "—" counters when the stats endpoint isn't reachable.
  Future<AdminStats> getDashboardStats() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.adminDashboardStats,
      );
      return AdminStats.fromJson(response.data ?? const {});
    } catch (e) {
      if (kDebugMode) debugPrint('[Admin] dashboard stats unavailable: $e');
      return const AdminStats.unavailable();
    }
  }

  // ── Students ──

  Future<AdminPage<AdminStudent>> getStudents({String? search, int page = 1}) =>
      _guard(() async {
        final response = await _dio.get<dynamic>(
          ApiEndpoints.adminStudents,
          queryParameters: {
            if (search != null && search.trim().isNotEmpty)
              'search': search.trim(),
            'page': page,
          },
        );
        return AdminPage.fromJson(response.data, AdminStudent.fromJson);
      });

  Future<AdminStudentDetails> getStudent(int id) => _guard(() async {
    final response = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.adminStudent(id),
    );
    return AdminStudentDetails.fromJson(response.data ?? const {});
  });

  /// Frees one of the student's registered device slots.
  Future<void> removeStudentDevice(int studentId, int deviceId) =>
      _guard(() async {
        await _dio.delete<dynamic>(
          ApiEndpoints.adminStudentDevice(studentId, deviceId),
        );
      });

  // ── Subjects ──

  Future<List<AdminSubject>> getSubjects() => _guard(() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.adminSubjects);
    return AdminPage.fromJson(response.data, AdminSubject.fromJson).items;
  });

  Future<void> updateSubject(int id, Map<String, dynamic> data) =>
      _guard(() async {
        await _dio.put<dynamic>(ApiEndpoints.adminSubject(id), data: data);
      });

  // ── Schedule ──

  Future<List<AdminSchedule>> getSchedules({String? week}) => _guard(() async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.adminSchedules,
      queryParameters: {'week': ?week},
    );
    return AdminPage.fromJson(response.data, AdminSchedule.fromJson).items;
  });

  Future<void> createSchedule(Map<String, dynamic> data) => _guard(() async {
    await _dio.post<dynamic>(ApiEndpoints.adminSchedules, data: data);
  });

  Future<void> updateSchedule(int id, Map<String, dynamic> data) =>
      _guard(() async {
        await _dio.put<dynamic>(ApiEndpoints.adminSchedule(id), data: data);
      });

  Future<void> deleteSchedule(int id) => _guard(() async {
    await _dio.delete<dynamic>(ApiEndpoints.adminSchedule(id));
  });

  // ── Subscriptions ──

  /// [status]: `active` / `expired` / `pending` / `cancelled`, or `null`
  /// for all.
  Future<AdminPage<AdminSubscription>> getSubscriptions({
    String? status,
    int page = 1,
  }) => _guard(() async {
    final response = await _dio.get<dynamic>(
      ApiEndpoints.adminSubscriptions,
      queryParameters: {'status': ?status, 'page': page},
    );
    return AdminPage.fromJson(response.data, AdminSubscription.fromJson);
  });

  /// `{student_id, subject_id, expires_at}` (`expires_at: null` = lifetime).
  Future<void> createSubscription(Map<String, dynamic> data) =>
      _guard(() async {
        await _dio.post<dynamic>(ApiEndpoints.adminSubscriptions, data: data);
      });

  /// Activate (`{status: active}`) or extend (`{expires_at}`).
  Future<void> updateSubscription(int id, Map<String, dynamic> data) =>
      _guard(() async {
        await _dio.put<dynamic>(ApiEndpoints.adminSubscription(id), data: data);
      });

  Future<void> cancelSubscription(int id) => _guard(() async {
    await _dio.delete<dynamic>(ApiEndpoints.adminSubscription(id));
  });

  // ── Announcements ──

  Future<List<AdminAnnouncement>> getAnnouncements() => _guard(() async {
    final response = await _dio.get<dynamic>(ApiEndpoints.adminAnnouncements);
    return AdminPage.fromJson(response.data, AdminAnnouncement.fromJson).items;
  });

  /// Multipart when [imagePath] is set, plain JSON otherwise.
  Future<void> createAnnouncement({
    required String title,
    required String body,
    required bool isActive,
    required bool sendPush,
    String? imagePath,
  }) => _guard(() async {
    final fields = <String, dynamic>{
      'title': title,
      'body': body,
      'is_active': isActive ? 1 : 0,
      'send_notification': sendPush ? 1 : 0,
    };
    await _dio.post<dynamic>(
      ApiEndpoints.adminAnnouncements,
      data: imagePath == null
          ? fields
          : FormData.fromMap({
              ...fields,
              'image': await MultipartFile.fromFile(imagePath),
            }),
    );
  });

  Future<void> updateAnnouncement(int id, Map<String, dynamic> data) =>
      _guard(() async {
        await _dio.put<dynamic>(ApiEndpoints.adminAnnouncement(id), data: data);
      });

  Future<void> deleteAnnouncement(int id) => _guard(() async {
    await _dio.delete<dynamic>(ApiEndpoints.adminAnnouncement(id));
  });

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404 || code == 405 || code == 501) {
        throw adminEndpointMissing;
      }
      if (code == 401 || code == 403) {
        throw const ServerFailure(
          'ليس لديك صلاحية الإدارة على هذا الحساب',
          statusCode: 403,
        );
      }
      throw failureOf(e);
    } on Failure {
      rethrow;
    } catch (e) {
      // Unexpected response shape (e.g. HTML instead of JSON).
      if (kDebugMode) debugPrint('[Admin] unexpected response: $e');
      throw const UnknownFailure('استجابة غير متوقعة من السيرفر');
    }
  }
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(dioClientProvider));
});
