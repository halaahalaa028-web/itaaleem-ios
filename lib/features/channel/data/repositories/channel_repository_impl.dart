import 'package:itaaleem/core/error/failure.dart';
import 'package:itaaleem/core/utils/result.dart';
import 'package:itaaleem/features/channel/data/datasources/channel_remote_data_source.dart';
import 'package:itaaleem/features/channel/domain/entities/channel_message.dart';
import 'package:itaaleem/features/channel/domain/repositories/channel_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChannelRepositoryImpl implements ChannelRepository {
  ChannelRepositoryImpl(this._remoteDataSource);

  final ChannelRemoteDataSource _remoteDataSource;

  @override
  Future<Result<List<ChannelMessage>>> getMessages() async {
    try {
      final messages = await _remoteDataSource.getMessages();
      return Ok(messages);
    } on DioException catch (e) {
      return Err(_failureOf(e));
    } catch (_) {
      return const Err(UnknownFailure('حدث خطأ ما، حاول مرة أخرى'));
    }
  }

  Failure _failureOf(DioException e) {
    final error = e.error;
    if (error is Failure) return error;
    return const NetworkFailure('تعذر الاتصال، تحقق من الإنترنت وحاول مرة أخرى');
  }
}

final channelRepositoryProvider = Provider<ChannelRepository>((ref) {
  final remoteDataSource = ref.watch(channelRemoteDataSourceProvider);
  return ChannelRepositoryImpl(remoteDataSource);
});
