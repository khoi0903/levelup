import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../data/sse/coach_sse_parser.dart';
import '../../domain/models/coach_models.dart';
import '../../domain/repositories/coach_repository.dart';

class ApiCoachRepository implements CoachRepository {
  final ApiClient client;

  ApiCoachRepository({required this.client});

  @override
  Future<CoachHistoryResponse> getHistory({String? before, int limit = 20}) async {
    final params = <String, dynamic>{'limit': limit};
    if (before != null) {
      params['before'] = before;
    }
    final response = await client.get<Map<String, dynamic>>(
      '/coach/messages',
      queryParameters: params,
    );
    return CoachHistoryResponse.fromJson(response.data!);
  }

  /// Backend chờ AI tối đa ~45 giây (2 lần gọi × 20 giây) rồi mới trả lời; mặc định 10 giây của ApiClient
  /// làm app báo lỗi mạng trong khi server vẫn đang viết. Stream cũng vậy: AI có thể im lặng lâu trước chữ đầu.
  static const _aiTimeout = Duration(seconds: 75);

  @override
  Future<SendCoachResponse> sendMessage(String text) async {
    final response = await client.post<Map<String, dynamic>>(
      '/coach/messages',
      data: {'text': text},
      options: Options(receiveTimeout: _aiTimeout),
    );
    return SendCoachResponse.fromJson(response.data!);
  }

  @override
  Stream<CoachStreamEvent> sendMessageStream(String text) async* {
    try {
      final response = await client.postStream(
        '/coach/messages/stream',
        data: {'text': text},
        options: Options(receiveTimeout: _aiTimeout),
      );
      final byteStream = response.data?.stream;
      if (byteStream != null) {
        yield* parseCoachSseByteStream(byteStream);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // 404 từ endpoint stream -> dùng POST /coach/messages (giữ nguyên luồng cũ)
        final fallback = await sendMessage(text);
        yield CoachDoneEvent(fallback);
        return;
      }
      rethrow;
    }
  }

  @override
  Future<PlanView> applyAction(String messageId) async {
    final response = await client.post<Map<String, dynamic>>(
      '/coach/messages/$messageId/actions/apply',
    );
    return PlanView.fromJson(response.data!);
  }
}
