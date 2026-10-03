import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _cheered = false;
  int _currentNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              AppStrings.homeDate,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              AppStrings.homeGreeting,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: const [
                              Icon(
                                Icons.local_fire_department,
                                size: 18,
                                color: AppColors.primaryDark,
                              ),
                              SizedBox(width: 4),
                              Text(
                                AppStrings.streakWeeks,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Card Tuần này (2/3 buổi)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                AppStrings.thisWeekTitle,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                AppStrings.thisWeekSessions,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _WeekDayDot(label: 'T2', status: _DayStatus.completed),
                              _WeekDayDot(label: 'T3', status: _DayStatus.pending),
                              _WeekDayDot(label: 'T4', status: _DayStatus.completed),
                              _WeekDayDot(label: 'T5', status: _DayStatus.pending),
                              _WeekDayDot(label: 'T6', status: _DayStatus.today),
                              _WeekDayDot(label: 'T7', status: _DayStatus.pending),
                              _WeekDayDot(label: 'CN', status: _DayStatus.pending),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Card Hôm nay · 18:30 (Buổi tập chính)
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 90,
                            decoration: BoxDecoration(
                              color: AppColors.borderLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Text(
                                '[Ảnh bài tập]',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            AppStrings.todayWorkoutHeader,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            AppStrings.todayWorkoutTitle,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            AppStrings.todayWorkoutMeta,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              AppStrings.todayCoachNote,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: AppColors.accentDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: () => context.push('/workout'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      AppStrings.btnStart,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => context.push('/workout?quick5=true'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.textPrimary,
                                    side: const BorderSide(
                                        color: AppColors.border, width: 1.5),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14),
                                  ),
                                  child: const Text(
                                    AppStrings.btnOnly5Min,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Card Buddy feed
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.borderLight,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 20,
                              color: AppColors.textSecondary,
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
                                    style: TextStyle(fontWeight: FontWeight.w700),
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
                                  content: Text(_cheered
                                      ? 'Đã gửi lời cổ vũ tới Lan! 🔥'
                                      : 'Đã hủy cổ vũ'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(17),
                            child: Container(
                              height: 34,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: _cheered
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: Text(
                                _cheered ? 'Đã cổ vũ' : AppStrings.btnCheer,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Card Calo còn lại
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border, width: 1.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text(
                                AppStrings.caloRemaining,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                AppStrings.caloValue,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.borderLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: 0.54,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(4),
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
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home,
                    label: AppStrings.navToday,
                    isSelected: _currentNavIndex == 0,
                    onTap: () => setState(() => _currentNavIndex = 0),
                  ),
                  _NavItem(
                    icon: Icons.restaurant_menu,
                    label: AppStrings.navNutrition,
                    isSelected: _currentNavIndex == 1,
                    onTap: () => setState(() => _currentNavIndex = 1),
                  ),
                  // Nút Chụp món ăn ở giữa
                  Transform.translate(
                    offset: const Offset(0, -14),
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tính năng chụp món ăn sẽ có ở Sprint sau'),
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
                              color: Color.fromRGBO(196, 70, 31, 0.35),
                              blurRadius: 10,
                              offset: Offset(0, 4),
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
                  _NavItem(
                    icon: Icons.chat_bubble_outline,
                    label: AppStrings.navCoach,
                    isSelected: _currentNavIndex == 2,
                    onTap: () => setState(() => _currentNavIndex = 2),
                  ),
                  _NavItem(
                    icon: Icons.bar_chart,
                    label: AppStrings.navProgress,
                    isSelected: _currentNavIndex == 3,
                    onTap: () => setState(() => _currentNavIndex = 3),
                  ),
                ],
              ),
            ),
          ],
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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: status == _DayStatus.completed
                ? AppColors.accent
                : (status == _DayStatus.today
                    ? Colors.transparent
                    : AppColors.borderLight),
            border: status == _DayStatus.today
                ? Border.all(color: AppColors.primary, width: 2.5)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: status == _DayStatus.today
                ? FontWeight.w700
                : FontWeight.w500,
            color: status == _DayStatus.today
                ? AppColors.primaryDark
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
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
