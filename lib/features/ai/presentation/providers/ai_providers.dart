import 'package:itaaleem/features/ai/data/repositories/ai_repository_impl.dart';
import 'package:itaaleem/features/ai/domain/usecases/ask_ai_usecase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final askAiUseCaseProvider = Provider<AskAiUseCase>((ref) {
  return AskAiUseCase(ref.watch(aiRepositoryProvider));
});
