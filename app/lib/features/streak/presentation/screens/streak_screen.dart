import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../controllers/streak_controller.dart';
import '../../domain/models/streak_models.dart';

/// Màn hình Streak tuần (F4).
class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chuỗi tuần (Streak)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: streakAsync.when(
            data: (streak) => _buildContent(context, ref, streak),
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            error: (err, _) => ErrorView(
              message: mapErrorMessage(err),
              onRetry: () => ref.invalidate(streakFutureProvider),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, StreakView streak) {
    final thisWeek = streak.thisWeek;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Main streak counter card
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 42,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${streak.currentWeeks} tuần liên tiếp',
                key: const ValueKey('streak-current-text'),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Kỷ lục cao nhất: ${streak.bestWeeks} tuần',
                key: const ValueKey('streak-best-text'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Thẻ đóng băng (Freeze cards)
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.ac_unit_rounded,
                  color: Color(0xFF0284C7),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thẻ đóng băng: ${streak.freezesAvailable} thẻ',
                      key: const ValueKey('streak-freezes-text'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tự động bảo vệ streak nếu bạn có một tuần bận rộn.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Tuần này
        if (thisWeek != null) ...[
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tuần này',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${thisWeek.completedSessions}/${thisWeek.targetSessions} buổi',
                      key: const ValueKey('streak-this-week-count'),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentLink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  child: LinearProgressIndicator(
                    value: thisWeek.targetSessions > 0
                        ? (thisWeek.completedSessions / thisWeek.targetSessions).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 8,
                    backgroundColor: AppColors.progressTrack,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.progressFill),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  thisWeek.completedSessions >= thisWeek.targetSessions
                      ? 'Đã hoàn thành mục tiêu tuần! Streak của bạn an toàn.'
                      : 'Còn ${thisWeek.targetSessions - thisWeek.completedSessions} buổi để giữ vững streak tuần.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Lịch sử 8 tuần
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Lịch sử 8 tuần gần nhất',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              if (streak.weeks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Chưa có lịch sử tuần trước.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                ...streak.weeks.map((week) => _buildWeekRow(week)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekRow(StreakWeek week) {
    IconData statusIcon;
    Color iconColor;
    Color iconBg;
    String statusLabel;

    switch (week.status) {
      case 'completed':
        statusIcon = Icons.check_circle_rounded;
        iconColor = AppColors.primary;
        iconBg = AppColors.primaryLight;
        statusLabel = 'Đạt mục tiêu';
        break;
      case 'frozen':
        statusIcon = Icons.ac_unit_rounded;
        iconColor = const Color(0xFF0284C7);
        iconBg = const Color(0xFFE0F2FE);
        statusLabel = 'Đã dùng đóng băng';
        break;
      case 'broken':
        statusIcon = Icons.remove_circle_outline_rounded;
        iconColor = Colors.grey;
        iconBg = const Color(0xFFF3F4F6);
        statusLabel = 'Bỏ lỡ';
        break;
      default:
        statusIcon = Icons.timelapse_rounded;
        iconColor = AppColors.accentLink;
        iconBg = AppColors.primaryLight;
        statusLabel = 'Đang diễn ra';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tuần bắt đầu ${week.weekStart}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${week.completedSessions}/${week.targetSessions} buổi',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
