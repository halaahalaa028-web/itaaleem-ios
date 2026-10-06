import 'package:itaaleem/features/update/domain/entities/app_version_info.dart';

/// Maps `GET /public/app-version` onto [AppVersionInfo]. Field names are
/// hedged defensively (the exact backend shape isn't pinned down in
/// APP_SPEC.md yet), the same way other public-endpoint models in this app
/// do.
class AppVersionInfoModel extends AppVersionInfo {
  const AppVersionInfoModel({
    required super.latestVersion,
    super.forceUpdate,
    super.updateUrl,
    super.message,
  });

  factory AppVersionInfoModel.fromJson(Map<String, dynamic> json) {
    return AppVersionInfoModel(
      latestVersion:
          (json['latest_version'] ?? json['version'] ?? json['latest'])
              as String? ??
          '',
      forceUpdate:
          (json['force_update'] ?? json['is_force_update'] ?? false) == true,
      updateUrl:
          (json['update_url'] ?? json['url'] ?? json['download_url'])
              as String?,
      message:
          (json['message'] ?? json['update_message'] ?? json['description'])
              as String?,
    );
  }
}
