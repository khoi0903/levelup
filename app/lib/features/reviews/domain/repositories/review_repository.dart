import '../../../onboarding/domain/models/plan_models.dart';
import '../models/review_models.dart';

abstract class ReviewRepository {
  Future<WeeklyReviewView> getLatestReview();
  Future<PlanView> submitDecision(String reviewId, ReviewDecisionRequest request);
}
