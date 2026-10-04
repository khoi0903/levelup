import '../../../../core/api/api_client.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../domain/models/review_models.dart';
import '../../domain/repositories/review_repository.dart';

class ApiReviewRepository implements ReviewRepository {
  final ApiClient client;

  ApiReviewRepository({required this.client});

  @override
  Future<WeeklyReviewView> getLatestReview() async {
    final response = await client.get<Map<String, dynamic>>('/reviews/latest');
    return WeeklyReviewView.fromJson(response.data!);
  }

  @override
  Future<PlanView> submitDecision(String reviewId, ReviewDecisionRequest request) async {
    final response = await client.post<Map<String, dynamic>>(
      '/reviews/$reviewId/decision',
      data: request.toJson(),
    );
    return PlanView.fromJson(response.data!);
  }
}
