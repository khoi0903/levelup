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
}
