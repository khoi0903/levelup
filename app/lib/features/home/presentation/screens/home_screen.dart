import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../../workout/presentation/controllers/workout_controller.dart';
import '../controllers/home_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _cheered = false;
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStatusFutureProvider);
    final planAsync = ref.watch(homePlanProvider);

    final me = userAsync.valueOrNull;
    final displayName = me?.displayName ?? 'Minh';
    final streakWeeks = me?.streak?.currentWeeks ?? 5;
    final dateText = me?.localDate ?? AppStrings.homeDate;

    final plan = planAsync.valueOrNull;
    final todaySession = plan == null
        ? null
        : pickNextSession(plan, localDateString(DateTime.now()));
    final todayDone = todaySession?.status == 'completed';
    final totalTarget = plan?.targetSessions ?? 3;
    final currentSessionsCount = plan == null
        ? 2
        : plan.sessions.where((s) => s.status == 'completed').length;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: Greeting + Streak badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dateText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Chào buổi chiều, $displayName',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusPill,
                              ),
                              border: Border.all(
                                color: AppColors.border,
                                width: 1.0,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.cardNormalShadow,
                                  blurRadius: 10,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.local_fire_department,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$streakWeeks tuần',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accentLink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Card Tuần này (2/3 buổi)
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        borderRadius: AppColors.radiusCard,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  AppStrings.thisWeekTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  '$currentSessionsCount/$totalTarget buổi',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                _WeekDayDot(
                                  label: 'T2',
                                  status: _DayStatus.completed,
                                ),
                                _WeekDayDot(
                                  label: 'T3',
                                  status: _DayStatus.pending,
                                ),
                                _WeekDayDot(
                                  label: 'T4',
                                  status: _DayStatus.completed,
                                ),
                                _WeekDayDot(
                                  label: 'T5',
                                  status: _DayStatus.pending,
                                ),
                                _WeekDayDot(
                                  label: 'T6',
                                  status: _DayStatus.today,
                                ),
                                _WeekDayDot(
                                  label: 'T7',
                                  status: _DayStatus.pending,
                                ),
                                _WeekDayDot(
                                  label: 'CN',
                                  status: _DayStatus.pending,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Card Hôm nay · 18:30 (Buổi tập chính)
                      GlassCard(
                        padding: const EdgeInsets.all(16),
                        borderRadius: AppColors.radiusCard,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.placeholder,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1.0,
                                ),
                              ),
                              child: const Center(
                                child: Text(
                                  '[Ảnh bài tập]',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              todaySession != null &&
                                      todaySession.scheduledTime.isNotEmpty
                                  ? 'Hôm nay · ${todaySession.scheduledTime}'
                                  : AppStrings.todayWorkoutHeader,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.accentLink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              todaySession?.title ??
                                  AppStrings.todayWorkoutTitle,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              todaySession != null
                                  ? '${todaySession.durationMin} phút · ${todaySession.items.length} động tác'
                                  : AppStrings.todayWorkoutMeta,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (todaySession != null &&
                                todaySession.items.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                todaySession.items
                                    .map((i) => i.nameVi ?? i.exerciseId)
                                    .join(' · '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1.0,
                                ),
                              ),
                              child: const Text(
                                AppStrings.todayCoachNote,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: PrimaryButton(
                                    // Tập xong hết buổi trong tuần vẫn được tập thêm
                                    label: todayDone
                                        ? 'Tập thêm'
                                        : AppStrings.btnStart,
                                    height: 48,
                                    onPressed: () => context.push(
                                      todaySession == null
                                          ? '/workout'
                                          : '/workout/${todaySession.id}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SecondaryButton(
                                  label: AppStrings.btnOnly5Min,
                                  height: 48,
                                  onPressed: todayDone
                                      ? null
                                      : () => context.push(
                                          todaySession == null
                                              ? '/workout?quick5=true'
                                              : '/workout/${todaySession.id}?quick5=true',
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Card Buddy feed
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        borderRadius: AppColors.radiusCard,
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryLight,
                                border: Border.all(
                                  color: AppColors.border,
                                  width: 1.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 20,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: AppStrings.buddyFeedPrefix,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    TextSpan(text: AppStrings.buddyFeedSuffix),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _cheered = !_cheered;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _cheered
                                          ? 'Đã gửi lời cổ vũ tới Lan! 🔥'
                                          : 'Đã hủy cổ vũ',
                                    ),
                                    duration: const Duration(seconds: 1),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusPill,
                              ),
                              child: Container(
                                height: 34,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _cheered
                                      ? AppColors.accentLink
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radiusPill,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: AppColors.btnShadow,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _cheered ? 'Đã cổ vũ' : AppStrings.btnCheer,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Card Calo còn lại
                      GlassCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        borderRadius: AppColors.radiusCard,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Expanded(
                                  child: Text(
                                    AppStrings.caloRemaining,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  AppStrings.caloValue,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Container(
                              height: 8,
                              decoration: BoxDecoration(
                                color: AppColors.progressTrack,
                                borderRadius: BorderRadius.circular(
                                  AppColors.radiusPill,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: 0.54,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.progressFill,
                                      borderRadius: BorderRadius.circular(
                                        AppColors.radiusPill,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Navigation Bar
              Container(
                height: 80,
                padding: const EdgeInsets.only(top: 8),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(color: AppColors.border, width: 1.0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _NavItem(
                        icon: Icons.home,
                        label: AppStrings.navToday,
                        isSelected: _currentNavIndex == 0,
                        onTap: () => setState(() => _currentNavIndex = 0),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.restaurant_menu,
                        label: AppStrings.navNutrition,
                        isSelected: _currentNavIndex == 1,
                        onTap: () => setState(() => _currentNavIndex = 1),
                      ),
                    ),
                    // Nút Chụp món ăn ở giữa
                    Transform.translate(
                      offset: const Offset(0, -14),
                      child: InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Tính năng chụp món ăn sẽ có ở Sprint sau',
                              ),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(26),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.btnShadow,
                                blurRadius: 16,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.chat_bubble_outline,
                        label: AppStrings.navCoach,
                        isSelected: _currentNavIndex == 2,
                        onTap: () => setState(() => _currentNavIndex = 2),
                      ),
                    ),
                    Expanded(
                      child: _NavItem(
                        icon: Icons.bar_chart,
                        label: AppStrings.navProgress,
                        isSelected: _currentNavIndex == 3,
                        onTap: () => setState(() => _currentNavIndex = 3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DayStatus { completed, pending, today }

class _WeekDayDot extends StatelessWidget {
  final String label;
  final _DayStatus status;

  const _WeekDayDot({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: status == _DayStatus.completed
                ? AppColors.primary
                : (status == _DayStatus.today
                      ? AppColors.surface
                      : AppColors.surface),
            border: status == _DayStatus.today
                ? Border.all(color: AppColors.primary, width: 2.0)
                : Border.all(
                    color: status == _DayStatus.completed
                        ? AppColors.primary
                        : AppColors.border,
                    width: 1.0,
                  ),
            boxShadow: status == _DayStatus.completed
                ? const [
                    BoxShadow(
                      color: AppColors.btnShadow,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: status == _DayStatus.completed
              ? const Icon(Icons.check, size: 18, color: Colors.white)
              : (status == _DayStatus.today
                    ? Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    : null),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: status == _DayStatus.today
                ? FontWeight.w700
                : FontWeight.w500,
            color: status == _DayStatus.today
                ? AppColors.accentLink
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected
                  ? AppColors.accentLink
                  : AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.accentLink
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
