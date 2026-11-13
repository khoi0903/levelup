import '../models/nutrition_models.dart';
import '../../data/photo/meal_photo.dart';

abstract interface class NutritionRepository {
  Future<NutritionToday> today();
  Future<List<Food>> search(String query);
  Future<Recognition> recognize(MealPhoto photo);

  /// Ghi món bằng câu: AI tách câu thành các món, trả cùng dạng với nhận diện ảnh.
  Future<Recognition> parseText(String text, String meal);

  /// Món hay được ghi cho một bữa (breakfast|lunch|dinner|snack).
  Future<List<Food>> popular(String meal, {int limit = 8});
  Future<NutritionToday> saveMeal(MealRequest request);
  Future<WaterResult> addWater(int ml);
}
