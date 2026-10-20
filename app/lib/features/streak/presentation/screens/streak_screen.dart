import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_palette.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../controllers/streak_controller.dart';
import '../../domain/models/streak_models.dart';

/// Màn hình Chuỗi tuần (Streak) - F4.
class StreakScreen extends ConsumerWidget {
  const StreakScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(streakFutureProvider);
    final streak = streakAsync.valueOrNull;

    ref.listen<AsyncValue<StreakView>>(streakFutureProvider, (prev, next) {
      if (next.hasError && streak != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(mapErrorMessage(next.error)),
              behavior: SnackBarBehavior.floating,
            ),
          );
      }
    });

    final isReloading = streakAsync.isLoading && streak != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chuỗi tuần (Streak)',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: context.colors.textPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: GradientBackground(
        child: SafeArea(
          child: streak == null
              ? (streakAsync.hasError
                  ? ErrorView(
                      message: mapErrorMessage(streakAsync.error),
                      onRetry: () => ref.invalidate(streakFutureProvider),
                    )
                  : const StreakScreenSkeleton())
              : Column(
                  children: [
                    ReloadingIndicator(isReloading: isReloading),
                    Expanded(
                      child: RefreshIndicator(
                        color: context.colors.primary,
                        onRefresh: () async {
                          ref.invalidate(streakFutureProvider);
                        },
                        child: _buildContent(context, ref, streak),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, StreakView streak) {
    final thisWeek = streak.thisWeek;
    final sortedWeeks = streak.weeks.toList()
      ..sort((a, b) => b.weekStart.compareTo(a.weekStart));

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.colors.primaryLight,
                ),
                child: Icon(
                  Icons.local_fire_department_rounded,
                  size: 42,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${streak.currentWeeks} tuần liên tiếp',
                key: const ValueKey('streak-current-text'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Kỷ lục cao nhất: ${streak.bestWeeks} tuần',
                key: const ValueKey('streak-best-text'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textSecondary,
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
                  color: context.colors.infoBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.ac_unit_rounded,
                  color: context.colors.infoAccent,
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
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tự động bảo vệ streak nếu bạn có một tuần bận rộn.',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textSecondary,
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
                    Text(
                      'Tuần này',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.colors.textPrimary,
                      ),
                    ),
                    Text(
                      '${thisWeek.completedSessions}/${thisWeek.targetSessions} buổi',
                      key: const ValueKey('streak-this-week-count'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.colors.accentLink,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  child: LinearProgressIndicator(
                    value: thisWeek.targetSessions > 0
                        ? (thisWeek.completedSessions / thisWeek.targetSessions)
                              .clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 8,
                    backgroundColor: context.colors.progressTrack,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      context.colors.progressFill,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  thisWeek.completedSessions >= thisWeek.targetSessions
                      ? 'Đã hoàn thành mục tiêu tuần! Streak của bạn an toàn.'
                      : 'Còn ${thisWeek.targetSessions - thisWeek.completedSessions} buổi để giữ vững streak tuần.',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Lịch sử: chỉ các tuần từ khi bắt đầu dùng (tối đa 8, máy chủ đã cắt)
        GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sortedWeeks.length <= 1
                    ? 'Tuần đầu tiên của bạn'
                    : 'Lịch sử ${sortedWeeks.length} tuần gần nhất',
                key: const ValueKey('streak-history-title'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              if (sortedWeeks.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text(
                      'Chưa có lịch sử tuần trước.',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                )
              else
                ...sortedWeeks.map((week) => _buildWeekRow(context, week)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWeekRow(BuildContext context, StreakWeek week) {
    final statusInfo = mapWeekStatus(week.status);
    final weekTitle = formatWeekRange(week.weekStart);

    return InkWell(
      key: ValueKey('streak-week-row-${week.weekStart}'),
      onTap: () => context.push('/streak/week/${week.weekStart}'),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusInfo.bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(statusInfo.icon, color: statusInfo.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    statusInfo.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusInfo.color,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${week.completedSessions}/${week.targetSessions} buổi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: context.colors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
