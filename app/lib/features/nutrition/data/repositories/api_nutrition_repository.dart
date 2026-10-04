import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../photo/meal_photo.dart';

class ApiNutritionRepository implements NutritionRepository {
  ApiNutritionRepository(this.client);
  final ApiClient client;
  @override
  Future<NutritionToday> today() async => NutritionToday.fromJson(
    (await client.get<Map<String, dynamic>>('/nutrition/today')).data!,
  );
  @override
  Future<List<Food>> search(String query) async =>
      (await client.get<List<dynamic>>(
        '/foods/search',
        queryParameters: {'q': query.trim()},
      )).data!.map((e) => Food.fromJson(e)).toList();
  @override
  Future<Recognition> recognize(MealPhoto photo) async => Recognition.fromJson(
    (await client.post<Map<String, dynamic>>(
      '/meals/recognize',
      data: photo.toJson(),
      options: Options(receiveTimeout: const Duration(seconds: 90)),
    )).data!,
  );
  @override
  Future<NutritionToday> saveMeal(MealRequest request) async =>
      NutritionToday.fromJson(
        (await client.post<Map<String, dynamic>>(
          '/meals',
          data: request.toJson(),
        )).data!,
      );
  @override
  Future<WaterResult> addWater(int ml) async => WaterResult.fromJson(
    (await client.post<Map<String, dynamic>>('/water', data: {'ml': ml})).data!,
  );
}
