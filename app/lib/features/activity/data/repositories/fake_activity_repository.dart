import '../../domain/models/activity_models.dart';
import '../../domain/repositories/activity_repository.dart';

class FakeActivityRepository implements ActivityRepository {
  final List<ActivitySyncRequest> sentRequests = [];
  ActivitySyncResponse? nextResponse;
  Exception? errorToThrow;
  ActivityToday today = const ActivityToday(localDate: '');
  List<ActivityDay> history = const [];
  int todayCalls = 0;

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

  @override
  Future<ActivityToday> getToday() async {
    todayCalls++;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return today;
  }

  @override
  Future<List<ActivityDay>> getHistory(int days) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return history;
  }
}
