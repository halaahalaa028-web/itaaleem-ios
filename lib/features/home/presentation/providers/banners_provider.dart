import 'package:itaaleem/core/providers/cache_for.dart';
import 'package:itaaleem/features/auth/presentation/providers/auth_controller.dart';
import 'package:itaaleem/features/home/data/datasources/banners_remote_data_source.dart';
import 'package:itaaleem/features/home/domain/entities/app_banner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The joined center's home-screen banners (`GET /banners`). A demo ("دخول
/// تجريبي") session never hits the network — [HomeScreen] falls back to the
/// static default banner whenever this resolves empty, errors, or (in demo)
/// is never watched for real data at all.
final bannersProvider = FutureProvider.autoDispose<List<AppBanner>>((
  ref,
) async {
  final isDemo = ref.watch(isDemoSessionProvider);
  if (isDemo) return const [];
  return ref.cached(() => ref.read(bannersRemoteDataSourceProvider).getBanners());
});
