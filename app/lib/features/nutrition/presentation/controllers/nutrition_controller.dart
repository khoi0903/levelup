import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/photo/meal_photo.dart';
import '../../data/repositories/api_nutrition_repository.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/nutrition_repository.dart';

import '../../../../core/utils/cache_for_extension.dart';

final nutritionRepositoryProvider = Provider<NutritionRepository>(
  (ref) => ApiNutritionRepository(ref.watch(apiClientProvider)),
);
final mealPhotoPickerProvider = Provider<MealPhotoPicker>(
  (ref) => PlatformMealPhotoPicker(),
);
final nutritionTodayProvider = FutureProvider.autoDispose<NutritionToday>(
  (ref) {
    ref.cacheFor(const Duration(minutes: 5));
    return ref.watch(nutritionRepositoryProvider).today();
  },
);
final foodSearchProvider = FutureProvider.autoDispose
    .family<List<Food>, String>(
      (ref, query) => query.trim().isEmpty
          ? Future.value([])
          : ref.watch(nutritionRepositoryProvider).search(query),
    );

/// Món phổ biến theo bữa; lỗi hay rỗng thì màn sửa bữa chỉ ẩn hàng gợi ý.
final popularFoodsProvider = FutureProvider.autoDispose
    .family<List<Food>, String>((ref, meal) {
      ref.cacheFor(const Duration(minutes: 10));
      return ref.watch(nutritionRepositoryProvider).popular(meal);
    });
