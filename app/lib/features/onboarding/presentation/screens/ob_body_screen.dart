import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/missing_hint.dart';
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
    _yearController = TextEditingController(
      text: state.birthYear?.toString() ?? '',
    );
    _heightController = TextEditingController(
      text: state.heightCm?.toString() ?? '',
    );
    _weightController = TextEditingController(
      text: state.startWeightKg?.toString() ?? '',
    );
    _goalWeightController = TextEditingController(
      text: state.goalWeightKg?.toString() ?? '',
    );
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
    final year = int.tryParse(_yearController.text);
    final height = int.tryParse(_heightController.text);
    final weight = int.tryParse(_weightController.text);
    final goalWeight = int.tryParse(_goalWeightController.text);

    ref
        .read(onboardingControllerProvider.notifier)
        .updateBodyInfo(
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

    final startWeight = state.startWeightKg;
    final goalWeight = state.goalWeightKg;
    final height = state.heightCm;

    final isHeightValid = height != null && height >= 80 && height <= 250;
    final isWeightValid =
        startWeight != null && startWeight >= 20 && startWeight <= 350;
    final isBodyValid = isHeightValid && isWeightValid;

    // Tính số tuần dự kiến dựa trên chênh lệch cân nặng nếu có đủ thông tin
    final int? estimatedWeeks;
    if (startWeight != null && goalWeight != null) {
      final diff = (startWeight - goalWeight).abs();
      estimatedWeeks = diff > 0 ? (diff / 0.5).round() : 4;
    } else {
      estimatedWeeks = null;
    }

    final String? missing = height == null
        ? 'Nhập chiều cao để tiếp tục'
        : !isHeightValid
        ? 'Chiều cao cần từ 80 đến 250 cm'
        : startWeight == null
        ? 'Nhập cân nặng hiện tại để tiếp tục'
        : !isWeightValid
        ? 'Cân nặng cần từ 20 đến 350 kg'
        : null;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingHeader(currentStep: 2),
                const SizedBox(height: 22),
                Text(
                  AppStrings.bodyTitle,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.bodySubtitle,
                  style: TextStyle(
                    fontSize: 15,
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.genderLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _GenderButton(
                                label: AppStrings.genderMale,
                                isSelected: state.gender == Gender.male,
                                onTap: () => controller.setGender(Gender.male),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _GenderButton(
                                label: AppStrings.genderFemale,
                                isSelected: state.gender == Gender.female,
                                onTap: () =>
                                    controller.setGender(Gender.female),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _GenderButton(
                                label: AppStrings.genderOther,
                                isSelected: state.gender == Gender.other,
                                onTap: () => controller.setGender(Gender.other),
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
                        if (goalWeight != null && estimatedWeeks != null) ...[
                          const SizedBox(height: 16),
                          GlassCard(
                            isSelected: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 14,
                            ),
                            borderRadius: AppColors.radiusButton,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.insights_rounded,
                                  color: context.colors.accent,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    AppStrings.bodyGoalNotice(
                                      goalWeight,
                                      estimatedWeeks,
                                    ),
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                MissingHint(missing),
                PrimaryButton(
                  label: AppStrings.btnContinue,
                  onPressed: isBodyValid
                      ? () {
                          _syncState();
                          context.push('/onboarding/shape');
                        }
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
    return GlassCard(
      isSelected: isSelected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12),
      borderRadius: AppColors.radiusButton,
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? context.colors.accentLink : context.colors.textPrimary,
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          borderRadius: AppColors.radiusButton,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: onChanged,
            style: TextStyle(
              fontSize: 16,
              color: context.colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}
