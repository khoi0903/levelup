import '../../../../core/api/api_client.dart';
import '../../../onboarding/domain/models/plan_models.dart';
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

  @override
  Future<SendCoachResponse> sendMessage(String text) async {
    final response = await client.post<Map<String, dynamic>>(
      '/coach/messages',
      data: {'text': text},
    );
    return SendCoachResponse.fromJson(response.data!);
  }

  @override
  Future<PlanView> applyAction(String messageId) async {
    final response = await client.post<Map<String, dynamic>>(
      '/coach/messages/$messageId/actions/apply',
    );
    return PlanView.fromJson(response.data!);
  }
}
