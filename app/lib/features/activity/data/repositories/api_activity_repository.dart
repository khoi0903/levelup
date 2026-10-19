import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../domain/models/activity_models.dart';
import '../../domain/repositories/activity_repository.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiActivityRepository(client);
});

class ApiActivityRepository implements ActivityRepository {
  final ApiClient client;

  ApiActivityRepository(this.client);

  @override
  Future<ActivitySyncResponse> syncTodayActivity(ActivitySyncRequest request) async {
    final res = await client.post('/activity/today', data: request.toJson());
    return ActivitySyncResponse.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<ActivityToday> getToday() async {
    final res = await client.get('/activity/today');
    return ActivityToday.fromJson(res.data as Map<String, dynamic>);
  }

  @override
  Future<List<ActivityDay>> getHistory(int days) async {
    final res = await client.get(
      '/activity/history',
      queryParameters: {'days': days},
    );
    return ((res.data as Map<String, dynamic>)['days'] as List)
        .map((e) => ActivityDay.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
