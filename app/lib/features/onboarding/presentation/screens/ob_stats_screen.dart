import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../body/domain/models/body_models.dart';
import '../../../body/domain/models/body_shape.dart';
import '../../../body/presentation/controllers/body_controller.dart';
import '../../../body/presentation/widgets/body_stats_view.dart';
import '../controllers/onboarding_controller.dart';

/// "Chỉ số của bạn": hiện một lần ngay sau màn kế hoạch (GET /me/body).
/// Máy chủ chưa trả được thì vẫn hiện phần tính được từ số đo vừa nhập.
class ObStatsScreen extends ConsumerWidget {
  const ObStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final async = ref.watch(bodyStatsProvider);
    final ob = ref.watch(onboardingControllerProvider);
    final target = ref.watch(onboardingResponseProvider)?.nutritionTarget;

    BodyStats local() => BodyStats(
      gender: ob.gender?.name,
      age: ob.birthYear == null ? null : DateTime.now().year - ob.birthYear!,
      heightCm: ob.heightCm?.toDouble(),
      weightKg: ob.startWeightKg?.toDouble(),
      bmi: computeBmi(ob.heightCm, ob.startWeightKg),
      bodyFatPct: ob.bodyFatPct?.toDouble(),
      targetKcal: target?.kcal,
      proteinG: target?.proteinG,
      carbsG: target?.carbsG,
      fatG: target?.fatG,
      waterMl: target?.waterMl,
      focusMuscles: ob.focusMuscles,
    );

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Chỉ số của bạn',
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tính từ số đo bạn vừa nhập. Chạm ⓘ để xem từng chỉ số nghĩa là gì. Bạn xem lại được trong tab Tôi.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: async.isLoading && !async.hasValue
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: BodyStatsView(
                            stats: async.valueOrNull ?? local(),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: AppStrings.btnContinue,
                  onPressed: () => context.push('/onboarding/notify'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
