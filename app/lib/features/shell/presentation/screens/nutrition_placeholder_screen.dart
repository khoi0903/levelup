import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/gradient_background.dart';

/// Màn hình tạm cho tab Dinh dưỡng (/nutrition) trong khi Codex hoàn thiện.
class NutritionPlaceholderScreen extends StatelessWidget {
  const NutritionPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dinh dưỡng',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: const GradientBackground(
        child: SafeArea(
          child: EmptyView(
            icon: Icons.restaurant_menu_rounded,
            title: 'Màn hình Dinh dưỡng',
            subtitle:
                'Tính năng theo dõi calo, nhận diện món ăn bằng ảnh và gợi ý bữa ăn sẽ sớm ra mắt.',
          ),
        ),
      ),
    );
  }
}
