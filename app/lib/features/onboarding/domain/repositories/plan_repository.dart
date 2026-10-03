import '../models/onboarding_models.dart';
import '../models/plan_models.dart';

abstract class PlanRepository {
  Future<WeeklyPlan> generateInitialPlan(OnboardingState state);
}
