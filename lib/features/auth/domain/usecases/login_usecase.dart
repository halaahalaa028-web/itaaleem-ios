import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/auth/domain/entities/student.dart';
import 'package:itaaleem/features/auth/domain/repositories/auth_repository.dart';

class LoginUseCase {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<Student>> call({
    required String mobile,
    required String password,
    String? fcmToken,
  }) {
    return _repository.login(
      mobile: mobile,
      password: password,
      fcmToken: fcmToken,
    );
  }
}
