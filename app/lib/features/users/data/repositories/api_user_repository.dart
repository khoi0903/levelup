import '../../../../core/api/api_client.dart';
import '../../domain/models/me_response.dart';
import '../../domain/models/settings_request.dart';
import '../../domain/repositories/user_repository.dart';

class ApiUserRepository implements UserRepository {
  final ApiClient client;

  ApiUserRepository(this.client);

  @override
  Future<MeResponse> getMe() async {
    final response = await client.get('/me');
    return MeResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<MeResponse> updateSettings(SettingsRequest request) async {
    final response = await client.patch('/me', data: request.toJson());
    return MeResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAccount() async {
    await client.delete('/me', data: {'confirm': true});
  }

  @override
  Future<PainFollowUpResponse> answerPainFollowUp(
    String bodyArea,
    String answer,
  ) async {
    final response = await client.post(
      '/pain-followups/$bodyArea',
      data: {'answer': answer},
    );
    return PainFollowUpResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
