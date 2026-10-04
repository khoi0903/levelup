import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/photo/meal_photo.dart';
import '../../data/repositories/api_nutrition_repository.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/nutrition_repository.dart';

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => ApiNutritionRepository(ref.watch(apiClientProvider)),
);
final mealPhotoPickerProvider = Provider<MealPhotoPicker>(
  (ref) => PlatformMealPhotoPicker(),
);
final nutritionTodayProvider = FutureProvider.autoDispose<NutritionToday>(
  (ref) => ref.watch(nutritionRepositoryProvider).today(),
);
final foodSearchProvider = FutureProvider.autoDispose
    .family<List<Food>, String>(
      (ref, query) => query.trim().isEmpty
          ? Future.value([])
          : ref.watch(nutritionRepositoryProvider).search(query),
    );
