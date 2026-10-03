import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/onboarding_models.dart';
import '../controllers/onboarding_controller.dart';

class ObBodyScreen extends ConsumerStatefulWidget {
  const ObBodyScreen({super.key});

  @override
  ConsumerState<ObBodyScreen> createState() => _ObBodyScreenState();
}

class _ObBodyScreenState extends ConsumerState<ObBodyScreen> {
  late final TextEditingController _yearController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _goalWeightController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingControllerProvider);
    _yearController = TextEditingController(text: state.birthYear.toString());
    _heightController = TextEditingController(text: state.heightCm.toString());
    _weightController = TextEditingController(text: state.startWeightKg.toString());
    _goalWeightController = TextEditingController(text: state.goalWeightKg.toString());
  }

  @override
  void dispose() {
    _yearController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _goalWeightController.dispose();
    super.dispose();
  }

  void _syncState() {
    final year = int.tryParse(_yearController.text) ?? 1998;
    final height = int.tryParse(_heightController.text) ?? 170;
    final weight = int.tryParse(_weightController.text) ?? 70;
    final goalWeight = int.tryParse(_goalWeightController.text) ?? 65;

    ref.read(onboardingControllerProvider.notifier).updateBodyInfo(
          birthYear: year,
          heightCm: height,
          startWeightKg: weight,
          goalWeightKg: goalWeight,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    // Tính số tuần dự kiến dựa trên chênh lệch cân nặng
    final diff = (state.startWeightKg - state.goalWeightKg).abs();
    final estimatedWeeks = diff > 0 ? (diff / 0.5).round() : 4;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingHeader(currentStep: 2),
              const SizedBox(height: 22),
              const Text(
                AppStrings.bodyTitle,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.bodySubtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        AppStrings.genderLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _GenderButton(
                              label: AppStrings.genderMale,
                              isSelected: state.gender == Gender.male,
                              onTap: () => controller.updateBodyInfo(gender: Gender.male),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GenderButton(
                              label: AppStrings.genderFemale,
                              isSelected: state.gender == Gender.female,
                              onTap: () => controller.updateBodyInfo(gender: Gender.female),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GenderButton(
                              label: AppStrings.genderOther,
                              isSelected: state.gender == Gender.other,
                              onTap: () => controller.updateBodyInfo(gender: Gender.other),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _NumberInputField(
                              label: AppStrings.birthYearLabel,
                              controller: _yearController,
                              onChanged: (_) => _syncState(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NumberInputField(
                              label: AppStrings.heightLabel,
                              controller: _heightController,
                              onChanged: (_) => _syncState(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _NumberInputField(
                              label: AppStrings.weightLabel,
                              controller: _weightController,
                              onChanged: (_) => _syncState(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _NumberInputField(
                              label: AppStrings.goalWeightLabel,
                              controller: _goalWeightController,
                              onChanged: (_) => _syncState(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          AppStrings.bodyGoalNotice(state.goalWeightKg, estimatedWeeks),
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PrimaryButton(
                label: AppStrings.btnContinue,
                onPressed: () {
                  _syncState();
                  context.push('/onboarding/training');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2.0 : 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _NumberInputField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _NumberInputField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.zero,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
