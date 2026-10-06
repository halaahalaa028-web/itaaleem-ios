import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/auth/domain/repositories/auth_repository.dart';

class DeleteAccountUseCase {
  const DeleteAccountUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() => _repository.deleteAccount();
}
