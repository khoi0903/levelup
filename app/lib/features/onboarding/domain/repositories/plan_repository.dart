import '../models/onboarding_models.dart';
import '../models/plan_models.dart';

abstract class PlanRepository {
  Future<PlanView> getCurrentPlan();
  Future<PlanView> generateInitialPlan(OnboardingState state);
}
