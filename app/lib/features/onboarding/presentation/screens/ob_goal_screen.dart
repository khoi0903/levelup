import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/onboarding_models.dart';
import '../controllers/onboarding_controller.dart';

class ObGoalScreen extends ConsumerWidget {
  const ObGoalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final goalOptions = [
      (
        UserGoal.lose_fat,
        AppStrings.goalLoseFatTitle,
        AppStrings.goalLoseFatDesc
      ),
      (
        UserGoal.build_muscle,
        AppStrings.goalBuildMuscleTitle,
        AppStrings.goalBuildMuscleDesc
      ),
      (
        UserGoal.get_healthier,
        AppStrings.goalGetHealthierTitle,
        AppStrings.goalGetHealthierDesc
      ),
      (
        UserGoal.maintain,
        AppStrings.goalMaintainTitle,
        AppStrings.goalMaintainDesc
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingHeader(currentStep: 1),
              const SizedBox(height: 24),
              const Text(
                AppStrings.goalTitle,
                style: TextStyle(
                  fontSize: 28,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.goalSubtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: goalOptions.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = goalOptions[index];
                    final isSelected = state.goal == item.$1;
                    return InkWell(
                      onTap: () => controller.selectGoal(item.$1),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primaryLight
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 2.0 : 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.$2,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.$3,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              PrimaryButton(
                label: AppStrings.btnContinue,
                onPressed: state.goal != null
                    ? () => context.push('/onboarding/body')
                    : null,
              ),
              const SizedBox(height: 14),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    AppStrings.alreadyHaveAccount,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng đăng nhập sẽ có ở Sprint sau'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Text(
                      AppStrings.logIn,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
