import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/channel/domain/entities/channel_message.dart';

abstract interface class ChannelRepository {
  /// `GET /channel`.
  Future<Result<List<ChannelMessage>>> getMessages();
}
