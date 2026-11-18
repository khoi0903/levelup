import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/missing_hint.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/selection_chip.dart';
import '../../../body/domain/models/body_shape.dart';
import '../../../body/presentation/widgets/body_figure.dart';
import '../../domain/models/onboarding_models.dart';
import '../../domain/coach_reactions.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/coach_reaction_line.dart';

class ObTrainingScreen extends ConsumerStatefulWidget {
  const ObTrainingScreen({super.key});

  @override
  ConsumerState<ObTrainingScreen> createState() => _ObTrainingScreenState();
}

class _ObTrainingScreenState extends ConsumerState<ObTrainingScreen> {
  /// Mục vừa chạm, để câu coach đi theo đúng mục đó.
  TrainingField? _last;

  void _touch(TrainingField field) {
    if (_last != field) setState(() => _last = field);
  }

  @override
  Widget build(BuildContext context) {
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

    final bodyShape = BodyShape.from(
      bmi: computeBmi(state.heightCm, state.startWeightKg),
      bodyFatPct: state.bodyFatPct,
      female: state.gender == Gender.female,
    );

    final String? missing = state.experience == null
        ? 'Chọn mức kinh nghiệm tập của bạn'
        : state.location == null
        ? 'Chọn nơi bạn sẽ tập'
        : null;

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
                Text(
                  AppStrings.trainingTitle,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                CoachReactionLine(trainingReaction(state, last: _last)),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Kinh nghiệm
                        Text(
                          AppStrings.expLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
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
                              onTap: () {
                                _touch(TrainingField.experience);
                                controller.updateTraining(experience: item.$1);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 2. Nơi tập
                        Text(
                          AppStrings.locationLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
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
                              onTap: () {
                                _touch(TrainingField.location);
                                controller.updateTraining(location: item.$1);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 3. Dụng cụ có sẵn
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 14,
                              color: context.colors.textPrimary,
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
                                  color: context.colors.textSecondary,
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
                                _touch(TrainingField.equipment);
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
                        Text(
                          AppStrings.injuryLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Chạm vào chỗ đang đau trên hình, hoặc chọn bên dưới.',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: PainMapPicker(
                            shape: bodyShape,
                            selected: {for (final i in state.injuries) i.name},
                            onToggle: (id) {
                              _touch(TrainingField.injuries);
                              controller.toggleInjury(
                                BodyArea.values.byName(id),
                              );
                            },
                            onClear: () {
                              _touch(TrainingField.injuries);
                              controller.clearInjuries();
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppStrings.injuryNote,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                MissingHint(missing),
                PrimaryButton(
                  label: AppStrings.btnContinue,
                  onPressed:
                      (state.experience != null && state.location != null)
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
