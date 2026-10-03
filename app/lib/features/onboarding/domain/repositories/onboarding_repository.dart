import '../models/onboarding_models.dart';

abstract class OnboardingRepository {
  Future<OnboardingResponse> completeOnboarding(OnboardingState state);
}
