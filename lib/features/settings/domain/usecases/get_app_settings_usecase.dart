import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/settings/domain/entities/app_settings.dart';
import 'package:itaaleem/features/settings/domain/repositories/settings_repository.dart';

class GetAppSettingsUseCase {
  const GetAppSettingsUseCase(this._repository);

  final SettingsRepository _repository;

  Future<Result<AppSettings>> call() => _repository.getAppSettings();
}
