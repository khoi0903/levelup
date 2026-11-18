import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/day_times_editor.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/onboarding_header.dart';
import '../../../../core/widgets/missing_hint.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/onboarding_models.dart';
import '../../domain/coach_reactions.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/coach_reaction_line.dart';

class ObScheduleScreen extends ConsumerStatefulWidget {
  const ObScheduleScreen({super.key, this.dayTimesInitiallyExpanded = false});

  /// Mở sẵn phần "Giờ riêng từng ngày" (dùng cho ảnh xem trước).
  final bool dayTimesInitiallyExpanded;

  @override
  ConsumerState<ObScheduleScreen> createState() => _ObScheduleScreenState();
}

class _ObScheduleScreenState extends ConsumerState<ObScheduleScreen> {
  /// Mục vừa chạm, để câu coach đi theo đúng mục đó.
  ScheduleField? _last;

  void _touch(ScheduleField field) {
    if (_last != field) setState(() => _last = field);
  }

  @override
  Widget build(BuildContext context) {
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
                Text(
                  AppStrings.scheduleTitle,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: context.colors.textPrimary,
                  ),
                ),
                CoachReactionLine(scheduleReaction(state, last: _last)),
                const SizedBox(height: 16),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Ngày trong tuần
                        Text(
                          AppStrings.daysOfWeekLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
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
                                  onTap: () {
                                    _touch(ScheduleField.days);
                                    controller.toggleWeekday(day.$1);
                                  },
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
                                            ? context.colors.accentLink
                                            : context.colors.textPrimary,
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
                        Text(
                          AppStrings.timeSlotLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Hai hàng, mỗi hàng hai thẻ cao bằng nhau; thẻ tự cao
                        // lên khi chữ phóng to nên không bị tràn.
                        for (var row = 0; row < timeSlots.length; row += 2) ...[
                          if (row > 0) const SizedBox(height: 10),
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (final slot in timeSlots.sublist(
                                  row,
                                  row + 2,
                                )) ...[
                                  if (slot != timeSlots[row])
                                    const SizedBox(width: 10),
                                  Expanded(
                                    child: GlassCard(
                                      isSelected: state.timeSlot == slot.$1,
                                      onTap: () {
                                        _touch(ScheduleField.slot);
                                        controller.setTimeSlot(slot.$1);
                                      },
                                      borderRadius: AppColors.radiusButton,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 20,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            slot.$2,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: context.colors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            slot.$3,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color:
                                                  context.colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (state.weekdays.isNotEmpty &&
                            state.timeSlot != null) ...[
                          const SizedBox(height: 12),
                          DayTimesEditor(
                            weekdays: state.weekdays,
                            slot: state.timeSlot!.name,
                            times: state.dayTimes,
                            onChanged: controller.setDayTime,
                            initiallyExpanded: widget.dayTimesInitiallyExpanded,
                          ),
                        ],
                        const SizedBox(height: 20),

                        // 3. Mỗi buổi bao lâu
                        Text(
                          AppStrings.durationLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textPrimary,
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
                                  onTap: () {
                                    _touch(ScheduleField.minutes);
                                    controller.setSessionMinutes(dur.$1);
                                  },
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
                                            ? context.colors.accentLink
                                            : context.colors.textPrimary,
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
                              Icon(
                                Icons.lightbulb_outline_rounded,
                                color: context.colors.accent,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppStrings.scheduleTip,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: context.colors.textPrimary,
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
