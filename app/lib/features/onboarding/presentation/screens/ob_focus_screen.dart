import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../body/domain/models/body_shape.dart';
import '../../../body/presentation/widgets/body_figure.dart';
import '../../domain/models/onboarding_models.dart';
import '../controllers/onboarding_controller.dart';

/// "Nhóm cơ bạn muốn cải thiện": chạm trên hình hoặc chọn chip. Bỏ qua được.
class ObFocusScreen extends ConsumerWidget {
  const ObFocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final c = context.colors;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingHeader(currentStep: 2),
                const SizedBox(height: 20),
                Text(
                  'Nhóm cơ bạn muốn cải thiện',
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chạm vào hình hoặc chọn bên dưới, chọn được nhiều nhóm. Coach sẽ ưu tiên các bài cho nhóm cơ này.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: MuscleMapPicker(
                      shape: BodyShape.from(
                        bmi: computeBmi(state.heightCm, state.startWeightKg),
                        bodyFatPct: state.bodyFatPct,
                        female: state.gender == Gender.female,
                      ),
                      selected: state.focusMuscles.toSet(),
                      onToggle: controller.toggleFocusMuscle,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: AppStrings.btnContinue,
                  onPressed: state.focusMuscles.isEmpty
                      ? null
                      : () => context.push('/onboarding/training'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const ValueKey('ob-focus-skip'),
                  onPressed: () {
                    controller.clearFocusMuscles();
                    context.push('/onboarding/training');
                  },
                  style: TextButton.styleFrom(foregroundColor: c.textSecondary),
                  child: const Text(
                    AppStrings.btnSkip,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
