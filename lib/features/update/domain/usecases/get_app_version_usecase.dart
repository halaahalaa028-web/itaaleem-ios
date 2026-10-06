import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/update/domain/entities/app_version_info.dart';
import 'package:itaaleem/features/update/domain/repositories/update_repository.dart';

class GetAppVersionUseCase {
  const GetAppVersionUseCase(this._repository);

  final UpdateRepository _repository;

  Future<Result<AppVersionInfo>> call() => _repository.getAppVersion();
}
