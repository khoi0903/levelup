import '../../../../core/api/api_client.dart';
import '../../domain/repositories/device_repository.dart';

class ApiDeviceRepository implements DeviceRepository {
  final ApiClient _client;

  ApiDeviceRepository(this._client);

  @override
  Future<void> registerDevice({
    required String token,
    required String platform,
  }) async {
    await _client.post(
      '/devices',
      data: {'token': token, 'platform': platform},
    );
  }
}
