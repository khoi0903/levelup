import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../domain/models/streak_models.dart';
import '../controllers/streak_controller.dart';

class StreakWeekDetailScreen extends ConsumerWidget {
  final String weekStart;

  const StreakWeekDetailScreen({super.key, required this.weekStart});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(streakWeekDetailProvider(weekStart));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chi tiết tuần',
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
          child: detailAsync.when(
            data: (detail) => _buildContent(context, ref, detail),
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            error: (err, _) => ErrorView(
              message: mapErrorMessage(err),
              onRetry: () =>
                  ref.invalidate(streakWeekDetailProvider(weekStart)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    StreakWeekDetail detail,
  ) {
    final statusInfo = mapWeekStatus(detail.status);
    final weekTitle = formatWeekRange(detail.weekStart);
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final days = detail.days.isNotEmpty ? detail.days : _generateFallbackDays();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        // Top summary card
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      weekTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusInfo.bgColor,
                      borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusInfo.icon,
                          size: 15,
                          color: statusInfo.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusInfo.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusInfo.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tiến độ tuần',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '${detail.completedSessions}/${detail.targetSessions} buổi',
                    key: const ValueKey('streak-detail-session-count'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentLink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
                child: LinearProgressIndicator(
                  value: detail.targetSessions > 0
                      ? (detail.completedSessions / detail.targetSessions)
                            .clamp(0.0, 1.0)
                      : 0.0,
                  minHeight: 7,
                  backgroundColor: AppColors.progressTrack,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.progressFill,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            'Lịch chi tiết 7 ngày',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 7 days
        ...days.map(
          (day) => _buildDayRow(context, day, isToday: day.date == todayStr),
        ),
      ],
    );
  }

  Widget _buildDayRow(
    BuildContext context,
    StreakDayDetail day, {
    required bool isToday,
  }) {
    final weekdayLabel = _weekdayName(day.weekday);
    final dateDisplay = _formatDayMonth(day.date);

    final hasSessions = day.sessions.isNotEmpty;
    final hasWorkouts = day.workouts.isNotEmpty;
    final isRestDay = !hasSessions && !hasWorkouts;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        isSelected: isToday,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header of day: weekday + date + (Hôm nay badge)
            Row(
              children: [
                Text(
                  '$weekdayLabel, $dateDisplay',
                  key: ValueKey('day-header-${day.weekday}'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w700,
                    color: isToday ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                if (isToday) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    ),
                    child: const Text(
                      'Hôm nay',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Content
            if (isRestDay)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Nghỉ',
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else ...[
              // Planned sessions
              ...day.sessions.map((s) => _buildSessionItem(s)),

              // Workouts
              ...day.workouts.map((w) => _buildWorkoutItem(w)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionItem(StreakSessionItem session) {
    final (statusText, statusColor) = _mapSessionStatus(session.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.fitness_center_rounded,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              session.scheduledTime != null && session.scheduledTime!.isNotEmpty
                  ? '${session.title} (${session.scheduledTime})'
                  : session.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutItem(StreakWorkoutItem workout) {
    final startTime = _formatTime(workout.startedAt);
    final isExtra = workout.plannedSessionId == null;
    final notCounted = !workout.countsForStreak;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 15,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              startTime.isNotEmpty ? '$startTime · ' : '',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${workout.durationMin} phút',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (isExtra) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Tập thêm',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (notCounted)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'dưới 5 phút, không tính streak',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  (String, Color) _mapSessionStatus(String status) {
    switch (status) {
      case 'completed':
        return ('Đã tập ✓', AppColors.primary);
      case 'skipped':
        return ('Bỏ', Colors.redAccent);
      case 'rest':
        return ('Nghỉ', AppColors.textSecondary);
      case 'rescheduled':
        return ('Đổi lịch', AppColors.accentLink);
      case 'planned':
      default:
        return ('Chưa tập', AppColors.textSecondary);
    }
  }

  String _weekdayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Thứ Hai';
      case 2:
        return 'Thứ Ba';
      case 3:
        return 'Thứ Tư';
      case 4:
        return 'Thứ Năm';
      case 5:
        return 'Thứ Sáu';
      case 6:
        return 'Thứ Bảy';
      case 7:
        return 'Chủ nhật';
      default:
        return 'Thứ $weekday';
    }
  }

  String _formatDayMonth(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  String _formatTime(String startedAt) {
    try {
      final dt = DateTime.parse(startedAt).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      if (startedAt.contains('T') && startedAt.length >= 16) {
        return startedAt.substring(11, 16);
      }
      return '';
    }
  }

  List<StreakDayDetail> _generateFallbackDays() {
    DateTime start;
    try {
      start = DateTime.parse(weekStart);
    } catch (_) {
      start = DateTime.now();
    }
    return List.generate(
      7,
      (i) => StreakDayDetail(
        date:
            '${start.add(Duration(days: i)).year}-${start.add(Duration(days: i)).month.toString().padLeft(2, '0')}-${start.add(Duration(days: i)).day.toString().padLeft(2, '0')}',
        weekday: i + 1,
        sessions: const [],
        workouts: const [],
      ),
    );
  }
}
