import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/onboarding_models.dart';
import '../controllers/onboarding_controller.dart';

class ObCoachScreen extends ConsumerWidget {
  const ObCoachScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final coachStyles = [
      (
        CoachStyle.strict,
        AppStrings.coachStrictTitle,
        AppStrings.coachStrictQuote,
      ),
      (
        CoachStyle.supportive,
        AppStrings.coachSupportiveTitle,
        AppStrings.coachSupportiveQuote,
      ),
      (
        CoachStyle.funny,
        AppStrings.coachFunnyTitle,
        AppStrings.coachFunnyQuote,
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
              const OnboardingHeader(currentStep: 6),
              const SizedBox(height: 20),
              const Text(
                AppStrings.coachTitle,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.coachSubtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: coachStyles.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = coachStyles[index];
                    final isSelected = state.coachStyle == item.$1;

                    return InkWell(
                      onTap: () => controller.setCoachStyle(item.$1),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.$2,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      AppStrings.coachSelectedBadge,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.surface
                                    : AppColors.background,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                  bottomLeft: Radius.circular(4),
                                ),
                              ),
                              child: Text(
                                item.$3,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AppColors.textMuted,
                                ),
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
                label: AppStrings.btnCreateMyPlan,
                onPressed: state.coachStyle != null
                    ? () => context.push('/onboarding/plan')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
