import 'package:itaaleem/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:itaaleem/features/auth/domain/usecases/delete_account_usecase.dart';
import 'package:itaaleem/features/auth/domain/usecases/get_profile_usecase.dart';
import 'package:itaaleem/features/auth/domain/usecases/login_usecase.dart';
import 'package:itaaleem/features/auth/domain/usecases/logout_usecase.dart';
import 'package:itaaleem/features/auth/domain/usecases/register_usecase.dart';
import 'package:itaaleem/features/auth/domain/usecases/update_password_usecase.dart';
import 'package:itaaleem/features/auth/domain/usecases/update_profile_usecase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final registerUseCaseProvider = Provider<RegisterUseCase>((ref) {
  return RegisterUseCase(ref.watch(authRepositoryProvider));
});

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(ref.watch(authRepositoryProvider));
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(ref.watch(authRepositoryProvider));
});

final getProfileUseCaseProvider = Provider<GetProfileUseCase>((ref) {
  return GetProfileUseCase(ref.watch(authRepositoryProvider));
});

final updateProfileUseCaseProvider = Provider<UpdateProfileUseCase>((ref) {
  return UpdateProfileUseCase(ref.watch(authRepositoryProvider));
});

final updatePasswordUseCaseProvider = Provider<UpdatePasswordUseCase>((ref) {
  return UpdatePasswordUseCase(ref.watch(authRepositoryProvider));
});

final deleteAccountUseCaseProvider = Provider<DeleteAccountUseCase>((ref) {
  return DeleteAccountUseCase(ref.watch(authRepositoryProvider));
});
