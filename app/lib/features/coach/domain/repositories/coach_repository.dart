import '../../data/sse/coach_sse_parser.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../models/coach_models.dart';

abstract class CoachRepository {
  Future<CoachHistoryResponse> getHistory({String? before, int limit = 20});
  Future<SendCoachResponse> sendMessage(String text);
  Stream<CoachStreamEvent> sendMessageStream(String text);
  Future<PlanView> applyAction(String messageId);
}
