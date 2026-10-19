import '../models/activity_models.dart';

abstract class ActivityRepository {
  Future<ActivitySyncResponse> syncTodayActivity(ActivitySyncRequest request);

  /// Số trên máy chủ hôm nay và giờ các buổi tập hôm nay.
  Future<ActivityToday> getToday();

  /// [days] ngày gần nhất (1–90), từ cũ tới mới.
  Future<List<ActivityDay>> getHistory(int days);
}
