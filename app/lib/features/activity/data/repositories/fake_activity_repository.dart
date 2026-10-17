import '../../domain/models/activity_models.dart';
import '../../domain/repositories/activity_repository.dart';

class FakeActivityRepository implements ActivityRepository {
  final List<ActivitySyncRequest> sentRequests = [];
  ActivitySyncResponse? nextResponse;
  Exception? errorToThrow;

  @override
  Future<ActivitySyncResponse> syncTodayActivity(ActivitySyncRequest request) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    sentRequests.add(request);
    return nextResponse ??
        ActivitySyncResponse(
          localDate: request.localDate,
          steps: request.steps,
          activeKcal: request.activeKcal,
          stored: true,
        );
  }
}
