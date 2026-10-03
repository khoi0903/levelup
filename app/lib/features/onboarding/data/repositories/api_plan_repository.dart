import '../../../../core/api/api_client.dart';
import '../../domain/models/onboarding_models.dart';
import '../../domain/models/plan_models.dart';
import '../../domain/repositories/plan_repository.dart';

class ApiPlanRepository implements PlanRepository {
  final ApiClient client;

  ApiPlanRepository(this.client);

  @override
  Future<PlanView> getCurrentPlan() async {
    final response = await client.get('/plans/current');
    return PlanView.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PlanView> generateInitialPlan(OnboardingState state) => getCurrentPlan();
}
