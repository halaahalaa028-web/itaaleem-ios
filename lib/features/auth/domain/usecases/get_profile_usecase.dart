import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/auth/domain/entities/student.dart';
import 'package:itaaleem/features/auth/domain/repositories/auth_repository.dart';

class GetProfileUseCase {
  const GetProfileUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<Student>> call() => _repository.getProfile();
}
