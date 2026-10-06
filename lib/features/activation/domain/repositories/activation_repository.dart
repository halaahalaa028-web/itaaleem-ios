import 'package:itaaleem/core/utils/result.dart';

abstract interface class ActivationRepository {
  /// Redeems an activation code via `POST /activation/redeem`. On success,
  /// returns the server's confirmation message.
  Future<Result<String>> redeem(String code);
}
