import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';

class ObStartScreen extends StatelessWidget {
  const ObStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final exercises = [
      (AppStrings.startEx1Title, AppStrings.startEx1Duration),
      (AppStrings.startEx2Title, AppStrings.startEx2Duration),
      (AppStrings.startEx3Title, AppStrings.startEx3Duration),
      (AppStrings.startEx4Title, AppStrings.startEx4Duration),
    ];

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const Text(
                  AppStrings.startReady,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.accentDark,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  AppStrings.startTitle,
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  AppStrings.startSubtitle,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),

                // Card preview bài tập 5 phút
                GlassCard(
                  padding: EdgeInsets.zero,
                  borderRadius: AppColors.radiusCard,
                  child: Column(
                    children: [
                      Container(
                        height: 140,
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppColors.radiusCard),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.fitness_center,
                              size: 36,
                              color: AppColors.primary,
                            ),
                            SizedBox(height: 6),
                            Text(
                              AppStrings.startWorkoutImagePlaceholder,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: exercises.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.$1,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.$2,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),
                PrimaryButton(
                  label: AppStrings.btnStart5Min,
                  onPressed: () => context.go('/workout'),
                ),
                const SizedBox(height: 10),
                SecondaryButton(
                  label: AppStrings.btnScheduleFirstSession,
                  height: 52,
                  onPressed: () => context.go('/home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
