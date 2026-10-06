import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/update/data/repositories/update_repository_impl.dart';
import 'package:itaaleem/features/update/domain/entities/app_version_info.dart';
import 'package:itaaleem/features/update/domain/usecases/get_app_version_usecase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final getAppVersionUseCaseProvider = Provider<GetAppVersionUseCase>((ref) {
  return GetAppVersionUseCase(ref.watch(updateRepositoryProvider));
});

/// `GET /public/app-version`, checked once after splash.
final appVersionInfoProvider = FutureProvider<AppVersionInfo>((ref) async {
  final useCase = ref.watch(getAppVersionUseCaseProvider);
  final result = await useCase();
  return switch (result) {
    Ok<AppVersionInfo>(:final value) => value,
    Err<AppVersionInfo>(:final failure) => throw failure,
  };
});

/// Whether the installed build (`package_info_plus`) is behind
/// [AppVersionInfo.latestVersion], and if so whether the update is
/// mandatory. Resolves to `null` when there's nothing to show (up to date,
/// or the version check itself failed/hasn't loaded — fails open so a
/// flaky endpoint never locks students out).
final updateStatusProvider = FutureProvider<UpdateStatus?>((ref) async {
  final info = await ref.watch(appVersionInfoProvider.future);
  if (info.latestVersion.isEmpty) return null;
  final packageInfo = await PackageInfo.fromPlatform();
  if (!_isNewer(info.latestVersion, packageInfo.version)) return null;
  return UpdateStatus(
    forceUpdate: info.forceUpdate,
    latestVersion: info.latestVersion,
    currentVersion: packageInfo.version,
    message: info.message,
    updateUrl: info.updateUrl,
  );
});

/// Compares two dotted version strings (`"1.2.10"` vs `"1.3.0"`)
/// numerically, segment by segment — a plain string compare would get
/// `"1.9.0" > "1.10.0"` wrong.
bool _isNewer(String latest, String current) {
  List<int> segments(String v) => v
      .split('.')
      .map((part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? '') ?? 0)
      .toList();

  final latestSegments = segments(latest);
  final currentSegments = segments(current);
  final length = latestSegments.length > currentSegments.length
      ? latestSegments.length
      : currentSegments.length;

  for (var i = 0; i < length; i++) {
    final l = i < latestSegments.length ? latestSegments[i] : 0;
    final c = i < currentSegments.length ? currentSegments[i] : 0;
    if (l != c) return l > c;
  }
  return false;
}

class UpdateStatus {
  const UpdateStatus({
    required this.forceUpdate,
    required this.latestVersion,
    required this.currentVersion,
    this.message,
    this.updateUrl,
  });

  final bool forceUpdate;
  final String latestVersion;
  final String currentVersion;
  final String? message;
  final String? updateUrl;
}

/// Whether the student has closed the soft-update banner this app session —
/// resets on cold start, so a still-pending optional update is offered
/// again next launch.
final updateBannerDismissedProvider = StateProvider<bool>((ref) => false);
