import '../../../../core/api/api_client.dart';
import '../../domain/models/food_candidate.dart';
import '../../domain/repositories/food_review_repository.dart';

class ApiFoodReviewRepository implements FoodReviewRepository {
  final ApiClient client;
  ApiFoodReviewRepository(this.client);

  @override
  Future<List<FoodCandidate>> pending() async {
    final res = await client.get('/admin/food-candidates');
    return (res.data as List)
        .map((e) => FoodCandidate.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> approve(String id, ApproveFood food) async {
    await client.post('/admin/food-candidates/$id/approve', data: food.toJson());
  }

  @override
  Future<void> reject(String id) async {
    await client.post('/admin/food-candidates/$id/reject');
  }
}
