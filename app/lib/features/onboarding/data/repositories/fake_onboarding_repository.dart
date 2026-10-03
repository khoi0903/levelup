import '../../domain/models/onboarding_models.dart';
import '../../domain/models/plan_models.dart';
import '../../domain/repositories/onboarding_repository.dart';
import 'fake_plan_repository.dart';

class FakeOnboardingRepository implements OnboardingRepository {
  final OnboardingResponse? response;
  final Exception? errorToThrow;

  FakeOnboardingRepository({this.response, this.errorToThrow});

  @override
  Future<OnboardingResponse> completeOnboarding(OnboardingState state) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (response != null) {
      return response!;
    }
    final plan = await FakePlanRepository().generateInitialPlan(state);
    return OnboardingResponse(
      userId: 'fake-user-id',
      displayName: state.displayName.isNotEmpty ? state.displayName : 'Minh',
      nutritionTarget: const NutritionTarget(
        kcal: 1800,
        proteinG: 120,
        carbsG: 200,
        fatG: 50,
        waterMl: 2500,
      ),
      plan: plan,
    );
  }
}
