import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../controllers/onboarding_controller.dart';

class ObStartScreen extends ConsumerWidget {
  const ObStartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tên vừa nhập ở onboarding; mở lại màn này sau đó thì lấy từ GET /me
    final typed = ref.watch(onboardingControllerProvider).displayName.trim();
    final name = typed.isNotEmpty
        ? typed
        : (ref.watch(currentUserProvider)?.displayName ?? '').trim();
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
                Text(
                  AppStrings.startReady,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.colors.accentLink,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppStrings.startTitle(name),
                  style: TextStyle(
                    fontSize: 28,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppStrings.startSubtitle,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: context.colors.textSecondary,
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
                        decoration: BoxDecoration(
                          color: context.colors.primaryLight,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(AppColors.radiusCard),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 36,
                              color: context.colors.primary,
                            ),
                            SizedBox(height: 6),
                            Text(
                              AppStrings.startWorkoutImagePlaceholder,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: context.colors.textSecondary,
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
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: context.colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    item.$2,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: context.colors.textSecondary,
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
