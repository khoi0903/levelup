import '../models/activity_models.dart';

abstract class ActivityRepository {
  Future<ActivitySyncResponse> syncTodayActivity(ActivitySyncRequest request);
}
