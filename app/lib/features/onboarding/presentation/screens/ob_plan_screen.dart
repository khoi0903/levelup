import '../../../product/presentation/widgets/product_widgets.dart';
import '../../../product/presentation/controllers/product_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../controllers/onboarding_controller.dart';

class ObPlanScreen extends ConsumerWidget {
  const ObPlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(userStatusFutureProvider);
    final planAsync = ref.watch(weeklyPlanFutureProvider);
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
                const OnboardingHeader(currentStep: 7),
                const SizedBox(height: 18),
                const Text(
                  AppStrings.planTitle,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  AppStrings.planSubtitle,
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
                      children: [
                        if (canRedeemReferral(ref)) const ReferralCodeInput(),
                        // Kế hoạch tuần 1 card
                        planAsync.when(
                          data: (plan) => GlassCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: List.generate(plan.sessions.length, (index) {
                                final session = plan.sessions[index];
                                final isLast = index == plan.sessions.length - 1;

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  decoration: BoxDecoration(
                                    border: isLast
                                        ? null
                                        : const Border(
                                            bottom: BorderSide(
                                              color: AppColors.borderLight,
                                              width: 1.0,
                                            ),
                                          ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppColors.cardSelectedBg,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: AppColors.cardSelectedBorder,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Text(
                                          session.dayLabel,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.accentLink,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (session.scheduledDate.isNotEmpty &&
                                                session.scheduledTime.isNotEmpty) ...[
                                              Text(
                                                '${session.scheduledDate} · ${session.scheduledTime}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.accentLink,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                            ],
                                            Text(
                                              session.title,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${session.durationMinutes} phút · ${session.exerciseCount} động tác',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            if (session.items.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                session.items
                                                    .map((i) => i.nameVi ?? i.exerciseId)
                                                    .join(' · '),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.textSecondary,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ),
                          ),
                          loading: () => const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          error: (error, stack) => const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),

                        // Injury notice
                        if (planAsync.valueOrNull?.injuryNote != null) ...[
                          GlassCard(
                            isSelected: true,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            borderRadius: AppColors.radiusButton,
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: AppColors.accent,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    planAsync.valueOrNull!.injuryNote!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Buddy invite box
                        GlassCard(
                          padding: const EdgeInsets.all(18),
                          borderRadius: AppColors.radiusCard,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                AppStrings.buddyInviteTitle,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                AppStrings.buddyInviteSubtitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.5,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: SecondaryButton(
                                      label: state.buddyInvited ? 'Đã mời' : AppStrings.btnInviteBuddy,
                                      height: 44,
                                      isDark: true,
                                      onPressed: () {
                                        controller.setBuddyInvited(true);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Đã tạo link mời buddy!'),
                                            duration: Duration(seconds: 1),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SecondaryButton(
                                      label: AppStrings.btnLater,
                                      height: 44,
                                      isDark: false,
                                      onPressed: () {
                                        controller.setBuddyInvited(false);
                                        context.push('/onboarding/notify');
                                      },
                                    ),
                                  ),
                                ],
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
