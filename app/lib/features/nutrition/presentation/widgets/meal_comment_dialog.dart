import 'package:flutter/material.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/nutrition_models.dart';

/// Tiêu đề và biểu tượng theo tình huống backend chọn (docs/content/meal-comments.json).
({String title, IconData icon}) mealCommentHeader(String situation) {
  return switch (situation) {
    'vuot_ngay' => (
      title: 'Hôm nay hơi quá đà',
      icon: Icons.local_fire_department_rounded,
    ),
    'gan_du' => (title: 'Gần chạm mục tiêu', icon: Icons.flag_rounded),
    'an_qua_it' => (title: 'Nhớ ăn đủ nhé', icon: Icons.restaurant_rounded),
    'an_khuya' => (title: 'Bữa khuya', icon: Icons.nightlight_round),
    'bua_nang' => (title: 'Bữa no nê', icon: Icons.lunch_dining_rounded),
    'nhieu_beo' => (title: 'Hơi nhiều dầu mỡ', icon: Icons.water_drop_rounded),
    'nhieu_tinh_bot' => (
      title: 'Nhiều tinh bột',
      icon: Icons.rice_bowl_rounded,
    ),
    'nhieu_dam' => (title: 'Giàu đạm', icon: Icons.fitness_center_rounded),
    'an_vat' => (title: 'Ăn vặt', icon: Icons.cookie_rounded),
    'bua_sang' => (title: 'Bữa sáng', icon: Icons.wb_sunny_rounded),
    'bua_nhe' => (title: 'Bữa nhẹ', icon: Icons.eco_rounded),
    _ => (title: 'Bữa cân đối', icon: Icons.check_circle_rounded),
  };
}

/// Popup câu nhận xét sau khi lưu bữa. Đóng bằng nút hoặc chạm ra ngoài.
Future<void> showMealCommentDialog(BuildContext context, MealComment comment) {
  final header = mealCommentHeader(comment.situation);
  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: ctx.colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ctx.colors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(header.icon, color: ctx.colors.primary, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              header.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: ctx.colors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              comment.text,
              key: const ValueKey('meal-comment-text'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: ctx.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Đã hiểu',
              height: 46,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      ),
    ),
  );
}
