import '../../../../core/api/api_client.dart';
import '../../domain/models/streak_models.dart';
import '../../domain/repositories/streak_repository.dart';

class ApiStreakRepository implements StreakRepository {
  final ApiClient client;

  ApiStreakRepository({required this.client});

  @override
  Future<StreakView> getStreak() async {
    final response = await client.get<Map<String, dynamic>>('/streak');
    return StreakView.fromJson(response.data!);
  }

  @override
  Future<StreakWeekDetail> getWeekDetail(String weekStart) async {
    final response = await client.get<Map<String, dynamic>>(
      '/streak/weeks/$weekStart',
    );
    return StreakWeekDetail.fromJson(response.data!);
  }
}
