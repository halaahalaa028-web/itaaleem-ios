import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/update/domain/entities/app_version_info.dart';

abstract interface class UpdateRepository {
  /// `GET /public/app-version`.
  Future<Result<AppVersionInfo>> getAppVersion();
}
