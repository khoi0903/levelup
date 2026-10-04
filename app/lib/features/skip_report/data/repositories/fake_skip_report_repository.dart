import '../../../onboarding/domain/models/plan_models.dart';
import '../../domain/models/skip_report_models.dart';
import '../../domain/repositories/skip_report_repository.dart';

class FakeSkipReportRepository implements SkipReportRepository {
  SkipReportResponse? customResponse;
  PlanView? customPlan;
  Exception? errorToThrow;
  SkipReportRequest? lastSkipRequest;
  PatchSessionRequest? lastPatchRequest;

  FakeSkipReportRepository({
    this.customResponse,
    this.customPlan,
    this.errorToThrow,
  });

  @override
  Future<SkipReportResponse> reportSkip(SkipReportRequest request) async {
    lastSkipRequest = request;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (customResponse != null) {
      return customResponse!;
    }

    String message;
    switch (request.reason) {
      case 'busy':
        message = 'Mình rút buổi tới còn 10 phút và dời buổi sau sang ngày trống.';
        break;
      case 'tired':
        message = 'Mình giảm cường độ các buổi còn lại trong tuần. Nghỉ ngơi đủ cũng là tập luyện.';
        break;
      case 'pain':
        message = 'Mình đã đổi sang bài an toàn cho vùng đau. Nếu đau kéo dài, bạn nên đi khám nhé.';
        break;
      case 'bored':
        message = 'Mình đổi sang bài mới cùng nhóm cơ cho các buổi còn lại.';
        break;
      case 'forgot':
        message = 'Bật nhắc trước buổi tập 60 phút nhé? Bạn có thể đổi trong cài đặt thông báo.';
        break;
      default:
        message = 'Cảm ơn bạn đã chia sẻ. Kế hoạch vẫn giữ nguyên, tập khi bạn sẵn sàng nhé.';
    }

    return SkipReportResponse(
      action: 'shortened',
      message: message,
      plan: customPlan ??
          PlanView(
            id: 'plan-1',
            weekStart: '2026-09-28',
            status: 'active',
            targetSessions: 3,
            sessions: [
              const SessionView(
                id: 's-1',
                scheduledDate: '2026-10-05',
                scheduledTime: '18:30',
                title: 'Toàn thân 10 phút',
                durationMin: 10,
                status: 'planned',
                adjustedReason: 'skip_busy',
              ),
            ],
          ),
    );
  }

  @override
  Future<PlanView> patchSession(String sessionId, PatchSessionRequest request) async {
    lastPatchRequest = request;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return customPlan ??
        PlanView(
          id: 'plan-1',
          weekStart: '2026-09-28',
          status: 'active',
          targetSessions: 3,
          sessions: [
            SessionView(
              id: sessionId,
              scheduledDate: request.scheduledDate ?? '2026-10-06',
              scheduledTime: request.scheduledTime ?? '19:00',
              title: request.action == 'rest' ? 'Nghỉ ngơi' : 'Toàn thân',
              durationMin: 15,
              status: request.action == 'rest' ? 'rest' : 'planned',
              adjustedReason: 'user_${request.action}',
            ),
          ],
        );
  }
}
