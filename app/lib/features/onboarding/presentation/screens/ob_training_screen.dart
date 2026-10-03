import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/selection_chip.dart';
import '../../domain/models/onboarding_models.dart';
import '../controllers/onboarding_controller.dart';

class ObTrainingScreen extends ConsumerWidget {
  const ObTrainingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final expOptions = [
      (Experience.beginner, AppStrings.expBeginner),
      (Experience.intermediate, AppStrings.expIntermediate),
      (Experience.regular, AppStrings.expRegular),
    ];

    final locationOptions = [
      (WorkoutLocation.home, AppStrings.locationHome),
      (WorkoutLocation.gym, AppStrings.locationGym),
      (WorkoutLocation.outdoor, AppStrings.locationOutdoor),
    ];

    final equipmentOptions = [
      (null, AppStrings.equipmentNone),
      (Equipment.dumbbell, AppStrings.equipmentDumbbell),
      (Equipment.mat, AppStrings.equipmentMat),
      (Equipment.resistance_band, AppStrings.equipmentBand),
      (Equipment.pullup_bar, AppStrings.equipmentPullupBar),
    ];

    final injuryOptions = [
      (null, AppStrings.injuryNone),
      (BodyArea.lower_back, AppStrings.injuryLowerBack),
      (BodyArea.knee, AppStrings.injuryKnee),
      (BodyArea.shoulder, AppStrings.injuryShoulder),
      (BodyArea.other, AppStrings.injuryOther),
    ];

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingHeader(currentStep: 3),
                const SizedBox(height: 20),
                const Text(
                  AppStrings.trainingTitle,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Kinh nghiệm
                        const Text(
                          AppStrings.expLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: expOptions.map((item) {
                            return SelectionChip(
                              label: item.$2,
                              isSelected: state.experience == item.$1,
                              onTap: () => controller.updateTraining(experience: item.$1),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 2. Nơi tập
                        const Text(
                          AppStrings.locationLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: locationOptions.map((item) {
                            return SelectionChip(
                              label: item.$2,
                              isSelected: state.location == item.$1,
                              onTap: () => controller.updateTraining(location: item.$1),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 3. Dụng cụ có sẵn
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: AppStrings.equipmentLabel,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: AppStrings.equipmentMultipleHint,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: equipmentOptions.map((item) {
                            final isNone = item.$1 == null;
                            final isSelected = isNone
                                ? state.equipment.isEmpty
                                : state.equipment.contains(item.$1);

                            return SelectionChip(
                              label: item.$2,
                              isSelected: isSelected,
                              onTap: () {
                                if (isNone) {
                                  controller.clearEquipment();
                                } else {
                                  controller.toggleEquipment(item.$1!);
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 4. Chấn thương
                        const Text(
                          AppStrings.injuryLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: injuryOptions.map((item) {
                            final isNone = item.$1 == null;
                            final isSelected = isNone
                                ? state.injuries.isEmpty
                                : state.injuries.contains(item.$1);

                            return SelectionChip(
                              label: item.$2,
                              isSelected: isSelected,
                              onTap: () {
                                if (isNone) {
                                  controller.clearInjuries();
                                } else {
                                  controller.toggleInjury(item.$1!);
                                }
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          AppStrings.injuryNote,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                PrimaryButton(
                  label: AppStrings.btnContinue,
                  onPressed: (state.experience != null && state.location != null)
                      ? () => context.push('/onboarding/schedule')
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
