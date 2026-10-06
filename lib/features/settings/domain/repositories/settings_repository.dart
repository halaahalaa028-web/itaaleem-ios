import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/settings/domain/entities/app_settings.dart';

abstract interface class SettingsRepository {
  /// `GET /settings`.
  Future<Result<AppSettings>> getAppSettings();
}
