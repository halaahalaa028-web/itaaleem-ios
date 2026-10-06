import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:itaaleem/features/settings/domain/entities/app_settings.dart';
import 'package:itaaleem/features/settings/domain/usecases/get_app_settings_usecase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final getAppSettingsUseCaseProvider = Provider<GetAppSettingsUseCase>((ref) {
  return GetAppSettingsUseCase(ref.watch(settingsRepositoryProvider));
});

/// `GET /settings`: contact/social links shown in the account tab.
final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final useCase = ref.watch(getAppSettingsUseCaseProvider);
  final result = await useCase();
  return switch (result) {
    Ok<AppSettings>(:final value) => value,
    Err<AppSettings>(:final failure) => throw failure,
  };
});
