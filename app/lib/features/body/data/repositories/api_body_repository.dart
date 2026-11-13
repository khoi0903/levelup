import '../../../../core/api/api_client.dart';
import '../../domain/models/body_models.dart';
import '../../domain/repositories/body_repository.dart';

class ApiBodyRepository implements BodyRepository {
  ApiBodyRepository(this.client);
  final ApiClient client;

  @override
  Future<BodyStats> getBody() async => BodyStats.fromJson(
    (await client.get<Map<String, dynamic>>('/me/body')).data!,
  );

  @override
  Future<MuscleWeek> getMusclesWeek({String? weekStart}) async =>
      MuscleWeek.fromJson(
        (await client.get<Map<String, dynamic>>(
          '/me/muscles/week',
          queryParameters: {'weekStart': ?weekStart},
        )).data!,
      );
}
