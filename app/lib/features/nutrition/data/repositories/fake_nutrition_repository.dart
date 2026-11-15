import '../../../../core/api/api_exceptions.dart';
import '../../domain/models/nutrition_models.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../photo/meal_photo.dart';

class FakeNutritionRepository implements NutritionRepository {
  FakeNutritionRepository({NutritionToday? initial, List<Food>? foods})
    : current =
          initial ??
          const NutritionToday(
            localDate: '2026-10-04',
            target: NutritionTarget(
              macros: Macros(kcal: 1800, proteinG: 110, carbsG: 200, fatG: 60),
              waterMl: 2000,
            ),
            remaining: Macros(kcal: 1800, proteinG: 110, carbsG: 200, fatG: 60),
          ),
      foods =
          foods ??
          const [
            Food(
              foodId: '000000000000000000000001',
              nameVi: 'Cơm trắng',
              servingDesc: '1 chén',
              servingGrams: 100,
              macros: Macros(kcal: 130, proteinG: 2.7, carbsG: 28, fatG: 0.3),
            ),
          ];
  NutritionToday current;
  final List<Food> foods;
  Object? todayError, searchError, recognitionError, saveError, waterError;

  /// Câu nhận xét trả kèm khi lưu bữa (null = backend không gửi).
  MealComment? saveComment;
  Recognition? recognition;
  MealRequest? savedRequest;
  MealPhoto? sentPhoto;
  String? lastQuery;
  int waterCalls = 0, saveCalls = 0;
  @override
  Future<NutritionToday> today() async {
    if (todayError != null) throw todayError!;
    return current;
  }

  @override
  Future<List<Food>> search(String query) async {
    lastQuery = query;
    if (searchError != null) throw searchError!;
    return foods;
  }

  @override
  Future<Recognition> recognize(MealPhoto photo) async {
    sentPhoto = photo;
    if (recognitionError != null) throw recognitionError!;
    return recognition ??
        Recognition(
          recognitionId: '000000000000000000000002',
          items: foods.map(MealItem.fromFood).toList(),
        );
  }

  @override
  Future<NutritionToday> saveMeal(MealRequest request) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    if (request.items.isEmpty || request.items.any((e) => !e.valid)) {
      throw const ApiException(code: 'VALIDATION_ERROR', statusCode: 400);
    }
    savedRequest = request;
    final total = request.items.fold(const Macros(), (a, b) => a + b.macros);
    final consumed = current.consumed + total;
    final target = current.target?.macros;
    current = NutritionToday(
      localDate: current.localDate,
      target: current.target,
      consumed: consumed,
      remaining: target == null ? null : target + consumed.scale(-1),
      waterMl: current.waterMl,
      meals: [
        ...current.meals,
        MealView(
          id: '$saveCalls',
          meal: request.meal,
          macros: total,
          names: request.items.map((e) => e.name).toList(),
        ),
      ],
      burnedKcal: current.burnedKcal,
      steps: current.steps,
      activeKcal: current.activeKcal,
      totalBurnedKcal: current.totalBurnedKcal,
    );
    final comment = saveComment;
    if (comment == null) return current;
    return NutritionToday(
      localDate: current.localDate,
      target: current.target,
      consumed: current.consumed,
      remaining: current.remaining,
      waterMl: current.waterMl,
      meals: current.meals,
      burnedKcal: current.burnedKcal,
      steps: current.steps,
      activeKcal: current.activeKcal,
      totalBurnedKcal: current.totalBurnedKcal,
      comment: comment,
    );
  }

  @override
  Future<WaterResult> addWater(int ml) async {
    waterCalls++;
    if (waterError != null) throw waterError!;
    current = current.withWater(current.waterMl + ml);
    return WaterResult(
      localDate: current.localDate,
      waterMl: current.waterMl,
      targetMl: current.target?.waterMl,
    );
  }
}
