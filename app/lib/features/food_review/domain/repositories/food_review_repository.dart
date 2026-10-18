import '../models/food_candidate.dart';

abstract class FoodReviewRepository {
  Future<List<FoodCandidate>> pending();
  Future<void> approve(String id, ApproveFood food);
  Future<void> reject(String id);
}
