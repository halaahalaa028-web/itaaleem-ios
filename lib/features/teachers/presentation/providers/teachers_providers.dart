import 'package:itaaleem/core/providers/cache_for.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/teachers/data/datasources/teachers_remote_data_source.dart';
import 'package:itaaleem/features/teachers/domain/entities/teacher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The joined center's teachers (`GET /teachers`) — a demo ("دخول تجريبي")
/// session never hits the network, since it has no real center membership
/// to scope the call to; [SubjectDetailScreen]'s demo path already renders
/// its own dummy teacher name instead of reading this.
final teachersProvider = FutureProvider.autoDispose<List<Teacher>>((
  ref,
) async {
  final isDemo = ref.watch(isDemoSessionProvider);
  if (isDemo) return const [];
  return ref.cached(() => ref.read(teachersRemoteDataSourceProvider).getTeachers());
});
