import 'package:itaaleem/core/network/api_endpoints.dart';
import 'package:itaaleem/core/network/dio_client.dart';
import 'package:itaaleem/features/ai/data/models/ai_answer_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AiRemoteDataSource {
  AiRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AiAnswerModel> ask(String question, {int? courseId}) async {
    if (kDebugMode) {
      debugPrint('>>> POST ${ApiEndpoints.aiAsk} question="$question" courseId=$courseId');
    }
    final response = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.aiAsk,
      data: {
        'question': question,
        if (courseId != null) 'course_id': courseId,
      },
    );
    if (kDebugMode) {
      debugPrint('>>> POST ${ApiEndpoints.aiAsk} response: ${response.data}');
    }
    return AiAnswerModel.fromJson(response.data ?? const {});
  }
}

final aiRemoteDataSourceProvider = Provider<AiRemoteDataSource>((ref) {
  return AiRemoteDataSource(ref.watch(dioClientProvider));
});
