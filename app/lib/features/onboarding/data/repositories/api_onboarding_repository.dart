import '../../../../core/api/api_client.dart';
import '../../domain/models/onboarding_models.dart';
import '../../domain/repositories/onboarding_repository.dart';

class ApiOnboardingRepository implements OnboardingRepository {
  final ApiClient client;

  ApiOnboardingRepository(this.client);

  @override
  Future<OnboardingResponse> completeOnboarding(OnboardingState state) async {
    final response = await client.post(
      '/onboarding',
      data: state.toOnboardingRequestJson(),
    );
    return OnboardingResponse.fromJson(response.data as Map<String, dynamic>);
  }
}
