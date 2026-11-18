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
import '../../domain/coach_reactions.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/coach_reaction_line.dart';

/// "Vóc dáng nào giống bạn nhất?": 5 hình theo chiều cao, cân nặng, giới tính
/// đã nhập. Bỏ qua được (backend tự ước tính tỉ lệ mỡ).
class ObShapeScreen extends ConsumerWidget {
  const ObShapeScreen({super.key});

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
                  'Vóc dáng nào giống bạn nhất?',
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Chọn hình gần giống nhất để LevelUp ước tính chỉ số cho sát hơn. Không có hình nào đúng hay sai.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: c.textSecondary,
                  ),
                ),
                CoachReactionLine(shapeReaction(state.bodyFatPct)),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: BodyShapePicker(
                      bmi: computeBmi(state.heightCm, state.startWeightKg),
                      female: state.gender == Gender.female,
                      selectedPct: state.bodyFatPct,
                      onSelected: controller.setBodyFatPct,
                    ),
                  ),
                ),
                PrimaryButton(
                  label: AppStrings.btnContinue,
                  onPressed: state.bodyFatPct == null
                      ? null
                      : () => context.push('/onboarding/focus'),
                ),
                const SizedBox(height: 4),
                TextButton(
                  key: const ValueKey('ob-shape-skip'),
                  onPressed: () {
                    controller.setBodyFatPct(null);
                    context.push('/onboarding/focus');
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
