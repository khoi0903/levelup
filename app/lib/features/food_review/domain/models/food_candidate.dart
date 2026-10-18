import '../../../nutrition/domain/models/nutrition_models.dart';

/// Món chưa có trong kho, chờ Admin duyệt (GET /admin/food-candidates).
class FoodCandidate {
  const FoodCandidate({
    required this.id,
    required this.nameVi,
    required this.userCount,
    required this.sightings,
    required this.saves,
    required this.readyForReview,
    this.suggested,
    this.typicalGrams,
  });
  final String id, nameVi;
  final int userCount, sightings, saves;

  /// Đủ số người dùng khác nhau để nên duyệt (ngưỡng do server quyết định).
  final bool readyForReview;

  /// Số gợi ý cho 100 g (trung vị các lần AI ước tính).
  final Macros? suggested;

  /// Khẩu phần người dùng hay lưu.
  final double? typicalGrams;

  factory FoodCandidate.fromJson(Map<String, dynamic> j) => FoodCandidate(
    id: j['id'] as String,
    nameVi: j['nameVi'] as String? ?? '',
    userCount: (j['userCount'] as num?)?.toInt() ?? 0,
    sightings: (j['sightings'] as num?)?.toInt() ?? 0,
    saves: (j['saves'] as num?)?.toInt() ?? 0,
    readyForReview: j['readyForReview'] == true,
    suggested: j['suggested'] == null
        ? null
        : Macros.fromJson(j['suggested'] as Map<String, dynamic>),
    typicalGrams: (j['typicalGrams'] as num?)?.toDouble(),
  );
}

/// Danh mục món, khớp mongo/seed/foods.json và validator backend.
const foodCategories = {
  'com': 'Cơm',
  'bun_pho_mi': 'Bún, phở, mì',
  'banh_mi': 'Bánh mì',
  'xoi': 'Xôi',
  'mon_canh': 'Món canh',
  'mon_chay': 'Món chay',
  'an_vat': 'Ăn vặt',
  'do_uong': 'Đồ uống',
  'trai_cay': 'Trái cây',
  'trang_mieng': 'Tráng miệng',
};

/// Giới hạn khớp MealDtos / FoodCandidateDtos.ApproveRequest ở backend.
const maxServingGrams = 3000.0;
const maxKcal = 3000.0;
const maxProteinG = 300.0;
const maxCarbsG = 500.0;
const maxFatG = 300.0;
const maxServingDescLength = 60;
const maxFoodNameLength = 100;

/// Số liệu cho một khẩu phần servingGrams (POST /admin/food-candidates/{id}/approve).
class ApproveFood {
  const ApproveFood({
    required this.nameVi,
    required this.category,
    required this.servingDesc,
    required this.servingGrams,
    required this.macros,
  });
  final String nameVi, category, servingDesc;
  final double servingGrams;
  final Macros macros;
  Map<String, dynamic> toJson() => {
    'nameVi': nameVi.trim(),
    'category': category,
    'servingDesc': servingDesc.trim(),
    'servingGrams': servingGrams,
    ...macros.toJson(),
  };
}
