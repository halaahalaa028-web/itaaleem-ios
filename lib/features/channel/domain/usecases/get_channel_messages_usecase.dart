import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/channel/domain/entities/channel_message.dart';
import 'package:itaaleem/features/channel/domain/repositories/channel_repository.dart';

class GetChannelMessagesUseCase {
  const GetChannelMessagesUseCase(this._repository);

  final ChannelRepository _repository;

  Future<Result<List<ChannelMessage>>> call() => _repository.getMessages();
}
