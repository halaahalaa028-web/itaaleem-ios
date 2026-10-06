import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/channel/data/repositories/channel_repository_impl.dart';
import 'package:itaaleem/features/channel/domain/entities/channel_message.dart';
import 'package:itaaleem/features/channel/domain/usecases/get_channel_messages_usecase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final getChannelMessagesUseCaseProvider = Provider<GetChannelMessagesUseCase>((
  ref,
) {
  return GetChannelMessagesUseCase(ref.watch(channelRepositoryProvider));
});

/// `GET /channel`'s last 50 messages, pinned ones first (newest first within
/// each group) so they stay glued to the top of the feed regardless of when
/// they were originally posted.
final channelMessagesProvider = FutureProvider<List<ChannelMessage>>((
  ref,
) async {
  final useCase = ref.watch(getChannelMessagesUseCaseProvider);
  final result = await useCase();
  final messages = switch (result) {
    Ok<List<ChannelMessage>>(:final value) => value,
    Err<List<ChannelMessage>>(:final failure) => throw failure,
  };
  final sorted = [...messages]
    ..sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.createdAt.compareTo(a.createdAt);
    });
  return sorted;
});
