import 'package:itaaleem/features/activation/data/repositories/activation_repository_impl.dart';
import 'package:itaaleem/features/activation/domain/usecases/redeem_activation_code_usecase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final redeemActivationCodeUseCaseProvider = Provider<RedeemActivationCodeUseCase>(
  (ref) {
    return RedeemActivationCodeUseCase(ref.watch(activationRepositoryProvider));
  },
);
