import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/primary_button.dart';

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
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                AppStrings.startTitle,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
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
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, width: 1.0),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      height: 140,
                      width: double.infinity,
                      color: AppColors.borderLight,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.fitness_center,
                            size: 36,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(height: 6),
                          Text(
                            AppStrings.startWorkoutImagePlaceholder,
                            style: TextStyle(
                              fontSize: 13,
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
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.$1,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontSize: 15,
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
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.go('/home'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.surface,
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    AppStrings.btnScheduleFirstSession,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
