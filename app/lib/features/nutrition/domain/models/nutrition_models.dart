double number(Map<String, dynamic> json, String key) =>
    (json[key] as num?)?.toDouble() ?? 0;

class Macros {
  const Macros({
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });
  final double kcal, proteinG, carbsG, fatG;
  factory Macros.fromJson(Map<String, dynamic> j) => Macros(
    kcal: number(j, 'kcal'),
    proteinG: number(j, 'proteinG'),
    carbsG: number(j, 'carbsG'),
    fatG: number(j, 'fatG'),
  );
  Macros scale(double factor) => Macros(
    kcal: kcal * factor,
    proteinG: proteinG * factor,
    carbsG: carbsG * factor,
    fatG: fatG * factor,
  );
  Macros operator +(Macros other) => Macros(
    kcal: kcal + other.kcal,
    proteinG: proteinG + other.proteinG,
    carbsG: carbsG + other.carbsG,
    fatG: fatG + other.fatG,
  );
  Map<String, dynamic> toJson() => {
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
  };
}

class NutritionTarget {
  const NutritionTarget({required this.macros, required this.waterMl});
  final Macros macros;
  final int waterMl;
  factory NutritionTarget.fromJson(Map<String, dynamic> j) => NutritionTarget(
    macros: Macros.fromJson(j),
    waterMl: (j['waterMl'] as num).toInt(),
  );
}

class Food {
  const Food({
    required this.foodId,
    required this.nameVi,
    required this.servingGrams,
    required this.macros,
    this.category = '',
    this.servingDesc = '',
  });
  final String foodId, nameVi, category, servingDesc;
  final double servingGrams;
  final Macros macros;
  factory Food.fromJson(Map<String, dynamic> j) => Food(
    foodId: j['foodId'] as String,
    nameVi: j['nameVi'] as String,
    category: j['category'] as String? ?? '',
    servingDesc: j['servingDesc'] as String? ?? '',
    servingGrams: number(j, 'servingGrams'),
    macros: Macros.fromJson(j),
  );
}

/// Base nutrition is for baseGrams; every edit scales from that original value.
class MealItem {
  const MealItem({
    required this.name,
    required this.grams,
    required this.baseGrams,
    this.foodId,
    this.baseMacros,
    this.kcalMin,
    this.kcalMax,
  });
  final String name;
  final String? foodId;
  final double grams, baseGrams;
  final Macros? baseMacros;
  final double? kcalMin, kcalMax;
  bool get matched => foodId != null && baseMacros != null;
  bool get valid => matched && grams.isFinite && grams >= 1 && grams <= 3000;
  Macros get macros => (baseMacros ?? const Macros()).scale(
    baseGrams > 0 ? grams / baseGrams : 1,
  );
  MealItem withGrams(double value) => MealItem(
    name: name,
    foodId: foodId,
    grams: value,
    baseGrams: baseGrams,
    baseMacros: baseMacros,
    kcalMin: kcalMin,
    kcalMax: kcalMax,
  );
  factory MealItem.fromFood(Food food) => MealItem(
    name: food.nameVi,
    foodId: food.foodId,
    grams: food.servingGrams,
    baseGrams: food.servingGrams,
    baseMacros: food.macros,
  );
  factory MealItem.fromRecognition(Map<String, dynamic> j) => MealItem(
    name: (j['nameVi'] ?? j['name']) as String,
    foodId: j['matched'] == true ? j['foodId'] as String? : null,
    grams: number(j, 'portionGrams'),
    baseGrams: number(j, 'portionGrams'),
    baseMacros: j['matched'] == true ? Macros.fromJson(j) : null,
    kcalMin: (j['kcalMin'] as num?)?.toDouble(),
    kcalMax: (j['kcalMax'] as num?)?.toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'foodId': foodId,
    'name': name,
    'portionGrams': grams,
    ...macros.toJson(),
  };
}

class Recognition {
  const Recognition({
    required this.recognitionId,
    required this.items,
    this.cached = false,
  });
  final String recognitionId;
  final bool cached;
  final List<MealItem> items;
  factory Recognition.fromJson(Map<String, dynamic> j) => Recognition(
    recognitionId: j['recognitionId'] as String,
    cached: j['cached'] as bool,
    items: (j['items'] as List)
        .map((e) => MealItem.fromRecognition(e))
        .toList(),
  );
}

const mealLabels = {
  'breakfast': 'Sáng',
  'lunch': 'Trưa',
  'dinner': 'Tối',
  'snack': 'Phụ',
};

class MealRequest {
  const MealRequest({
    required this.meal,
    required this.method,
    required this.items,
    this.recognitionId,
  });
  final String meal, method;
  final String? recognitionId;
  final List<MealItem> items;
  Map<String, dynamic> toJson() => {
    'meal': meal,
    'method': method,
    if (recognitionId != null) 'recognitionId': recognitionId,
    'items': items.map((e) => e.toJson()).toList(),
  };
}

class MealView {
  const MealView({
    required this.id,
    required this.meal,
    required this.macros,
    required this.names,
    this.eatenAt,
  });
  final String id, meal;
  final String? eatenAt;
  final Macros macros;
  final List<String> names;
  factory MealView.fromJson(Map<String, dynamic> j) => MealView(
    id: j['id'] as String,
    meal: j['meal'] as String,
    eatenAt: j['eatenAt'] as String?,
    macros: Macros.fromJson(j),
    names: (j['items'] as List).map((e) => e['name'] as String).toList(),
  );
}

class DinnerSuggestion {
  const DinnerSuggestion({required this.message, required this.foods});
  final String message;
  final List<Food> foods;
  factory DinnerSuggestion.fromJson(Map<String, dynamic> j) => DinnerSuggestion(
    message: j['message'] as String,
    foods: (j['foods'] as List).map((e) => Food.fromJson(e)).toList(),
  );
}

class NutritionToday {
  const NutritionToday({
    required this.localDate,
    this.target,
    this.consumed = const Macros(),
    this.remaining,
    this.waterMl = 0,
    this.meals = const [],
    this.suggestion,
    this.burnedKcal = 0,
    this.steps = 0,
    this.activeKcal = 0,
    int? totalBurnedKcal,
  }) : totalBurnedKcal = totalBurnedKcal ?? (burnedKcal > 0 ? burnedKcal : 0);

  final String localDate;
  final NutritionTarget? target;
  final Macros consumed;
  final Macros? remaining;
  final int waterMl;
  final List<MealView> meals;
  final DinnerSuggestion? suggestion;
  final int burnedKcal;
  final int steps;
  final int activeKcal;
  final int totalBurnedKcal;

  NutritionToday withWater(int value) => NutritionToday(
    localDate: localDate,
    target: target,
    consumed: consumed,
    remaining: remaining,
    waterMl: value,
    meals: meals,
    suggestion: suggestion,
    burnedKcal: burnedKcal,
    steps: steps,
    activeKcal: activeKcal,
    totalBurnedKcal: totalBurnedKcal,
  );

  factory NutritionToday.fromJson(Map<String, dynamic> j) => NutritionToday(
    localDate: j['localDate'] as String? ?? '',
    target: j['target'] == null ? null : NutritionTarget.fromJson(j['target']),
    consumed: j['consumed'] == null ? const Macros() : Macros.fromJson(j['consumed']),
    remaining: j['remaining'] == null ? null : Macros.fromJson(j['remaining']),
    waterMl: (j['waterMl'] as num?)?.toInt() ?? 0,
    meals: (j['meals'] as List?)?.map((e) => MealView.fromJson(e)).toList() ?? const [],
    suggestion: j['suggestion'] == null
        ? null
        : DinnerSuggestion.fromJson(j['suggestion']),
    burnedKcal: (j['burnedKcal'] as num?)?.toInt() ?? 0,
    steps: (j['steps'] as num?)?.toInt() ?? 0,
    activeKcal: (j['activeKcal'] as num?)?.toInt() ?? 0,
    totalBurnedKcal: (j['totalBurnedKcal'] as num?)?.toInt() ??
        (j['burnedKcal'] as num?)?.toInt() ??
        0,
  );
}

class WaterResult {
  const WaterResult({
    required this.localDate,
    required this.waterMl,
    this.targetMl,
  });
  final String localDate;
  final int waterMl;
  final int? targetMl;
  factory WaterResult.fromJson(Map<String, dynamic> j) => WaterResult(
    localDate: j['localDate'] as String,
    waterMl: (j['waterMl'] as num).toInt(),
    targetMl: (j['targetMl'] as num?)?.toInt(),
  );
}
