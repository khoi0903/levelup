import '../../../../core/api/api_client.dart';
import '../../domain/models/progress_models.dart';
import '../../domain/repositories/progress_repository.dart';

class ApiProgressRepository implements ProgressRepository {
  ApiProgressRepository(this.client);
  final ApiClient client;
  @override
  Future<MeasurementHistory> history({int days = 90}) async =>
      MeasurementHistory.fromJson(
        (await client.get<Map<String, dynamic>>(
          '/measurements',
          queryParameters: {'days': days},
        )).data!,
      );
  @override
  Future<MeasurementSaveResult> save(MeasurementRequest request) async =>
      MeasurementSaveResult.fromJson(
        (await client.post<Map<String, dynamic>>(
          '/measurements',
          data: request.toJson(),
        )).data!,
      );
}
