import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/selection_chip.dart';
import '../controllers/onboarding_controller.dart';

class ObWhyScreen extends ConsumerStatefulWidget {
  const ObWhyScreen({super.key});

  @override
  ConsumerState<ObWhyScreen> createState() => _ObWhyScreenState();
}

class _ObWhyScreenState extends ConsumerState<ObWhyScreen> {
  late final TextEditingController _whyController;

  final reasonOptions = const [
    AppStrings.reasonMirror,
    AppStrings.reasonOldClothes,
    AppStrings.reasonPlayWithKids,
    AppStrings.reasonDoctorAdvice,
    AppStrings.reasonLessFatigue,
    AppStrings.reasonUpcomingEvent,
  ];

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingControllerProvider);
    _whyController = TextEditingController(text: state.motivationText);
  }

  @override
  void dispose() {
    _whyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const OnboardingHeader(currentStep: 5),
              const SizedBox(height: 20),
              const Text(
                AppStrings.whyTitle,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                AppStrings.whySubtitle,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: reasonOptions.map((reason) {
                          final isSelected =
                              state.motivationReasons.contains(reason);
                          return SelectionChip(
                            label: reason,
                            isSelected: isSelected,
                            onTap: () => controller.toggleMotivationReason(reason),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                            fontFamily: 'Be Vietnam Pro',
                          ),
                          children: [
                            TextSpan(
                              text: AppStrings.whyCustomLabel,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: AppStrings.whyCustomOptional,
                              style: TextStyle(
                                fontWeight: FontWeight.w400,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.border, width: 1.5),
                        ),
                        child: TextField(
                          controller: _whyController,
                          maxLines: 3,
                          onChanged: (val) => controller.setMotivationText(val),
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AppColors.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(14),
                            hintText: AppStrings.whyCustomDefault,
                            hintStyle: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppColors.border, width: 1.0),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.borderLight,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: AppColors.textSecondary,
                                  ),
                                  children: [
                                    TextSpan(text: AppStrings.coachExamplePrefix),
                                    TextSpan(
                                      text: AppStrings.coachExampleQuote,
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              PrimaryButton(
                label: AppStrings.btnContinue,
                onPressed: () {
                  controller.setMotivationText(_whyController.text);
                  context.push('/onboarding/coach');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
