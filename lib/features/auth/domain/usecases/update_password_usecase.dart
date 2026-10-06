import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/auth/domain/repositories/auth_repository.dart';

class UpdatePasswordUseCase {
  const UpdatePasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) => _repository.updatePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
    newPasswordConfirmation: newPasswordConfirmation,
  );
}
