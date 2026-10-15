import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/missing_hint.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../buddies/presentation/controllers/buddy_controller.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../streak/presentation/controllers/streak_controller.dart';
import '../../domain/models/onboarding_models.dart';
import '../controllers/onboarding_controller.dart';

class ObCoachScreen extends ConsumerStatefulWidget {
  const ObCoachScreen({super.key});

  @override
  ConsumerState<ObCoachScreen> createState() => _ObCoachScreenState();
}

class _ObCoachScreenState extends ConsumerState<ObCoachScreen> {
  bool _isLoading = false;

  Future<void> _submitOnboarding(OnboardingState state) async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(onboardingRepositoryProvider);
      final response = await repo.completeOnboarding(state);
      ref.read(onboardingResponseProvider.notifier).state = response;
      // Màn khởi động đã tải trước các API này khi chưa onboarding (404): tải lại theo hồ sơ mới
      ref.invalidate(homePlanProvider);
      ref.invalidate(streakFutureProvider);
      ref.invalidate(buddyTodayFutureProvider);
      if (mounted) {
        context.push('/onboarding/plan');
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      final String message;
      if (e.fields.isNotEmpty) {
        message = e.fields.entries
            .map((entry) => '${entry.key}: ${entry.value}')
            .join('\n');
      } else if (e.code == 'NETWORK_ERROR') {
        message = 'Không kết nối được máy chủ';
      } else {
        message = e.code;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $message'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã có lỗi xảy ra: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: GradientBackground(
        child: SafeArea(
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
                    fontWeight: FontWeight.w800,
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
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final item = coachStyles[index];
                      final isSelected = state.coachStyle == item.$1;

                      return GlassCard(
                        isSelected: isSelected,
                        onTap: _isLoading
                            ? null
                            : () => controller.setCoachStyle(item.$1),
                        padding: const EdgeInsets.all(18),
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
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                GlassRadio(isSelected: isSelected),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.surface
                                    : AppColors.background,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(14),
                                  topRight: Radius.circular(14),
                                  bottomRight: Radius.circular(14),
                                  bottomLeft: Radius.circular(4),
                                ),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                item.$3,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                MissingHint(
                  state.coachStyle == null
                      ? 'Chọn phong cách coach bạn thích'
                      : null,
                ),
                PrimaryButton(
                  label: AppStrings.btnCreateMyPlan,
                  isLoading: _isLoading,
                  onPressed: (state.coachStyle != null && !_isLoading)
                      ? () => _submitOnboarding(state)
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
