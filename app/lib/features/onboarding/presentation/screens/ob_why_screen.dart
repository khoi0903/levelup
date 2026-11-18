import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/selection_chip.dart';
import '../../domain/coach_reactions.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/coach_reaction_line.dart';

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
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingHeader(currentStep: 5),
                const SizedBox(height: 20),
                Text(
                  AppStrings.whyTitle,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.whySubtitle,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: context.colors.textSecondary,
                  ),
                ),
                CoachReactionLine(
                  whyReaction(state.motivationReasons, state.motivationText),
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
                        const SizedBox(height: 20),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.textPrimary,
                            ),
                            children: [
                              TextSpan(
                                text: AppStrings.whyCustomLabel,
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                text: AppStrings.whyCustomOptional,
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: context.colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlassCard(
                          borderRadius: AppColors.radiusButton,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: TextField(
                            controller: _whyController,
                            maxLines: 3,
                            onChanged: (val) => controller.setMotivationText(val),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                              color: context.colors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 10),
                              hintText: AppStrings.whyCustomDefault,
                              hintStyle: TextStyle(
                                color: context.colors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        GlassCard(
                          borderRadius: AppColors.radiusButton,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: context.colors.primaryLight,
                                  border: Border.all(color: context.colors.border, width: 1.0),
                                ),
                                child: Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: context.colors.accent,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: context.colors.textSecondary,
                                    ),
                                    children: [
                                      TextSpan(text: AppStrings.coachExamplePrefix),
                                      TextSpan(
                                        text: AppStrings.coachExampleQuote,
                                        style: TextStyle(
                                          color: context.colors.textPrimary,
                                          fontWeight: FontWeight.w600,
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
      ),
    );
  }
}
