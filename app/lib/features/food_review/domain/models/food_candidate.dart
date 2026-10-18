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
  final bool readyForReview;

  /// Số gợi ý cho 100 g: kcal, proteinG, carbsG, fatG.
  final Map<String, double>? suggested;
  final double? typicalGrams;

  factory FoodCandidate.fromJson(Map<String, dynamic> j) {
    final s = j['suggested'] as Map<String, dynamic>?;
    return FoodCandidate(
      id: j['id'] as String,
      nameVi: j['nameVi'] as String? ?? '',
      userCount: (j['userCount'] as num?)?.toInt() ?? 0,
      sightings: (j['sightings'] as num?)?.toInt() ?? 0,
      saves: (j['saves'] as num?)?.toInt() ?? 0,
      readyForReview: j['readyForReview'] == true,
      suggested: s == null
          ? null
          : {
              for (final k in ['kcal', 'proteinG', 'carbsG', 'fatG'])
                k: (s[k] as num?)?.toDouble() ?? 0,
            },
      typicalGrams: (j['typicalGrams'] as num?)?.toDouble(),
    );
  }
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

/// Số liệu cho một khẩu phần servingGrams (POST /admin/food-candidates/{id}/approve).
class ApproveFood {
  const ApproveFood({
    required this.nameVi,
    required this.category,
    required this.servingDesc,
    required this.servingGrams,
    required this.kcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
  final String nameVi, category, servingDesc;
  final double servingGrams, kcal, proteinG, carbsG, fatG;
  Map<String, dynamic> toJson() => {
    'nameVi': nameVi.trim(),
    'category': category,
    'servingDesc': servingDesc.trim(),
    'servingGrams': servingGrams,
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
  };
}
