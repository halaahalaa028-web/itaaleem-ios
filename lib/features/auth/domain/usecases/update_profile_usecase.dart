import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/auth/domain/entities/student.dart';
import 'package:itaaleem/features/auth/domain/repositories/auth_repository.dart';

class UpdateProfileUseCase {
  const UpdateProfileUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<Student>> call({
    required String fullName,
    String? mobile,
    String? email,
    String? avatarFilePath,
  }) => _repository.updateProfile(
    fullName: fullName,
    mobile: mobile,
    email: email,
    avatarFilePath: avatarFilePath,
  );
}
