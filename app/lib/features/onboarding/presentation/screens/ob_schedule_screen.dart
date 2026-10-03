import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/onboarding_header.dart';
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
        AppStrings.slotEarlyMorningTime
      ),
      (
        TimeSlot.noon,
        AppStrings.slotNoonTitle,
        AppStrings.slotNoonTime
      ),
      (
        TimeSlot.evening,
        AppStrings.slotEveningTitle,
        AppStrings.slotEveningTime
      ),
      (
        TimeSlot.late_evening,
        AppStrings.slotLateEveningTitle,
        AppStrings.slotLateEveningTime
      ),
    ];

    final durations = [
      (15, AppStrings.duration1015),
      (20, AppStrings.duration20),
      (30, AppStrings.duration30),
      (45, AppStrings.duration45Plus),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                  fontWeight: FontWeight.w700,
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
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: weekdays.map((day) {
                          final isSelected = state.weekdays.contains(day.$1);
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 3),
                              child: InkWell(
                                onTap: () => controller.toggleWeekday(day.$1),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryLight
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: isSelected ? 2.0 : 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    day.$2,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primaryDark
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
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1.85,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: timeSlots.map((slot) {
                          final isSelected = state.timeSlot == slot.$1;
                          return InkWell(
                            onTap: () => controller.setTimeSlot(slot.$1),
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: isSelected ? 2.0 : 1.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    slot.$2,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    slot.$3,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
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
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: durations.map((dur) {
                          final isSelected = state.sessionMinutes == dur.$1;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: InkWell(
                                onTap: () => controller.setSessionMinutes(dur.$1),
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 48,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primaryLight
                                        : AppColors.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: isSelected ? 2.0 : 1.5,
                                    ),
                                  ),
                                  child: Text(
                                    dur.$2,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? AppColors.primaryDark
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Gợi ý tuần đầu
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text(
                          AppStrings.scheduleTip,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.accentDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              PrimaryButton(
                label: AppStrings.btnContinue,
                onPressed: (state.weekdays.isNotEmpty &&
                        state.timeSlot != null &&
                        state.sessionMinutes != null)
                    ? () => context.push('/onboarding/why')
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
