import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:itaaleem/features/admin/data/models/admin_models.dart';
import 'package:itaaleem/features/admin/data/repositories/admin_repository.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';

export 'package:itaaleem/features/admin/data/repositories/admin_repository.dart'
    show adminRepositoryProvider, isAdminEndpointMissing;

/// Whether the signed-in user gets the "الإدارة" tab and `/admin/*` routes —
/// by the server's `role`, falling back to `AdminConfig.adminPhones` (see
/// `Student.isAdmin`). Watched via `.select` so unrelated profile changes
/// don't rebuild the shell.
final isAdminProvider = Provider<bool>((ref) {
  return ref.watch(
    authControllerProvider.select(
      (state) => state.valueOrNull?.isAdmin ?? false,
    ),
  );
});

/// The joined center's name, for the dashboard greeting — from the profile
/// the app already has, so it shows even before the stats load.
final adminCenterNameProvider = Provider<String?>((ref) {
  return ref.watch(
    authControllerProvider.select((state) {
      final name = state.valueOrNull?.centerJson?['name'];
      return name is String && name.isNotEmpty ? name : null;
    }),
  );
});

final adminStatsProvider = FutureProvider.autoDispose<AdminStats>((ref) {
  if (!ref.watch(isAdminProvider)) return const AdminStats.unavailable();
  return ref.read(adminRepositoryProvider).getDashboardStats();
});

final adminStudentDetailsProvider = FutureProvider.autoDispose
    .family<AdminStudentDetails, int>((ref, id) {
      return ref.read(adminRepositoryProvider).getStudent(id);
    });

final adminSubjectsProvider = FutureProvider.autoDispose<List<AdminSubject>>((
  ref,
) {
  return ref.read(adminRepositoryProvider).getSubjects();
});

final adminSchedulesProvider = FutureProvider.autoDispose<List<AdminSchedule>>((
  ref,
) {
  return ref.read(adminRepositoryProvider).getSchedules(week: 'current');
});

final adminAnnouncementsProvider =
    FutureProvider.autoDispose<List<AdminAnnouncement>>((ref) {
      return ref.read(adminRepositoryProvider).getAnnouncements();
    });
