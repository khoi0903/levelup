import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/missing_hint.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/onboarding_models.dart';
import '../controllers/onboarding_controller.dart';

class ObScheduleScreen extends ConsumerWidget {
  const ObScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final weekdays = [
      (1, AppStrings.weekdayMon),
      (2, AppStrings.weekdayTue),
      (3, AppStrings.weekdayWed),
      (4, AppStrings.weekdayThu),
      (5, AppStrings.weekdayFri),
      (6, AppStrings.weekdaySat),
      (7, AppStrings.weekdaySun),
    ];

    final timeSlots = [
      (
        TimeSlot.early_morning,
        AppStrings.slotEarlyMorningTitle,
        AppStrings.slotEarlyMorningTime,
      ),
      (TimeSlot.noon, AppStrings.slotNoonTitle, AppStrings.slotNoonTime),
      (
        TimeSlot.evening,
        AppStrings.slotEveningTitle,
        AppStrings.slotEveningTime,
      ),
      (
        TimeSlot.late_evening,
        AppStrings.slotLateEveningTitle,
        AppStrings.slotLateEveningTime,
      ),
    ];

    final durations = [
      (15, AppStrings.duration1015),
      (20, AppStrings.duration20),
      (30, AppStrings.duration30),
      (45, AppStrings.duration45Plus),
    ];

    final String? missing = state.weekdays.isEmpty
        ? 'Chọn ít nhất một ngày rảnh trong tuần'
        : state.timeSlot == null
        ? 'Chọn khung giờ bạn hay tập'
        : state.sessionMinutes == null
        ? 'Chọn thời lượng mỗi buổi'
        : null;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const OnboardingHeader(currentStep: 4),
                const SizedBox(height: 20),
                const Text(
                  AppStrings.scheduleTitle,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Ngày trong tuần
                        const Text(
                          AppStrings.daysOfWeekLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: weekdays.map((day) {
                            final isSelected = state.weekdays.contains(day.$1);
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2.5,
                                ),
                                child: GlassCard(
                                  isSelected: isSelected,
                                  onTap: () => controller.toggleWeekday(day.$1),
                                  borderRadius: 14,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Center(
                                    child: Text(
                                      day.$2,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.accentLink
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 2. Khung giờ thường tập
                        const Text(
                          AppStrings.timeSlotLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GridView.count(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.85,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          children: timeSlots.map((slot) {
                            final isSelected = state.timeSlot == slot.$1;
                            return GlassCard(
                              isSelected: isSelected,
                              onTap: () => controller.setTimeSlot(slot.$1),
                              borderRadius: AppColors.radiusButton,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    slot.$2,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    slot.$3,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        // 3. Mỗi buổi bao lâu
                        const Text(
                          AppStrings.durationLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: durations.map((dur) {
                            final isSelected = state.sessionMinutes == dur.$1;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: GlassCard(
                                  isSelected: isSelected,
                                  onTap: () =>
                                      controller.setSessionMinutes(dur.$1),
                                  borderRadius: 14,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Center(
                                    child: Text(
                                      dur.$2,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.accentLink
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // Gợi ý tuần đầu
                        GlassCard(
                          isSelected: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          borderRadius: AppColors.radiusButton,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                color: AppColors.accent,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: const Text(
                                  AppStrings.scheduleTip,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
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
                MissingHint(missing),
                PrimaryButton(
                  label: AppStrings.btnContinue,
                  onPressed:
                      (state.weekdays.isNotEmpty &&
                          state.timeSlot != null &&
                          state.sessionMinutes != null)
                      ? () => context.push('/onboarding/why')
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
