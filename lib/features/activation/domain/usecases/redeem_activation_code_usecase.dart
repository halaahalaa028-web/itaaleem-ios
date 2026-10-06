import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/activation/domain/repositories/activation_repository.dart';

class RedeemActivationCodeUseCase {
  const RedeemActivationCodeUseCase(this._repository);

  final ActivationRepository _repository;

  Future<Result<String>> call(String code) => _repository.redeem(code);
}
