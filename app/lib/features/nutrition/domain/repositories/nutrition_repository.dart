import '../models/nutrition_models.dart';
import '../../data/photo/meal_photo.dart';

abstract interface class NutritionRepository {
  Future<NutritionToday> today();
  Future<List<Food>> search(String query);
  Future<Recognition> recognize(MealPhoto photo);
  Future<NutritionToday> saveMeal(MealRequest request);
  Future<WaterResult> addWater(int ml);
}
