import '../../../../core/api/api_client.dart';
import '../../domain/models/checkin_models.dart';
import '../../domain/repositories/checkin_repository.dart';

class ApiCheckinRepository implements CheckinRepository {
  final ApiClient client;

  ApiCheckinRepository({required this.client});

  @override
  Future<CheckinResponse> completeCheckin(CheckinRequest request) async {
    final response = await client.post<Map<String, dynamic>>(
      '/checkins',
      data: request.toJson(),
    );
    return CheckinResponse.fromJson(response.data!);
  }
}
