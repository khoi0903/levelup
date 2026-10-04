import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/models/workout_models.dart';
import '../controllers/workout_controller.dart';
import '../widgets/workout_widgets.dart';

/// Màn Kết quả (F2): thời lượng, streak, tiến độ tuần, kỷ lục, huy hiệu.
class WorkoutResultScreen extends ConsumerWidget {
  const WorkoutResultScreen({super.key});

  void _home(BuildContext context, WidgetRef ref) {
    // Làm mới Home để buổi vừa tập hiện là đã xong.
    ref.invalidate(homePlanProvider);
    ref.invalidate(userStatusFutureProvider);
    ref.read(activeWorkoutProvider.notifier).clear();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(activeWorkoutProvider)?.result;
    if (result == null) {
      return Scaffold(
        body: GradientBackground(
          child: Center(
            child: TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('Về trang chủ'),
            ),
          ),
        ),
      );
    }
    final week = result.week;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home(context, ref);
      },
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        size: 56,
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Xong buổi tập!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bạn đã tập ${formatDurationVi(result.durationSec)}',
                        key: const ValueKey('result-duration'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TipBox(
                        icon: result.countsForStreak
                            ? Icons.local_fire_department_rounded
                            : Icons.info_outline_rounded,
                        child: Text(
                          result.countsForStreak
                              ? 'Buổi này được tính vào streak tuần.'
                              : 'Buổi dưới 5 phút không tính streak. Lần sau cố thêm chút nữa nhé!',
                          key: const ValueKey('streak-note'),
                        ),
                      ),
                      if (week != null) ...[
                        const SizedBox(height: 14),
                        _WeekCard(week: week),
                      ],
                      if (result.personalRecords.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const _SectionTitle('Kỷ lục mới'),
                        for (final pr in result.personalRecords)
                          _RecordTile(record: pr),
                      ],
                      if (result.newAchievements.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.celebration_rounded, color: Color(0xFFD97706), size: 28),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Ăn mừng thành tích! Bạn vừa mở khóa huy hiệu mới.',
                                  key: ValueKey('achievement-celebration-banner'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        const _SectionTitle('Huy hiệu mới'),
                        for (final a in result.newAchievements)
                          _AchievementTile(achievement: a),
                      ],
                      if (result.personalRecords.isEmpty &&
                          result.newAchievements.isEmpty) ...[
                        const SizedBox(height: 14),
                        const TipBox(
                          icon: Icons.favorite_outline_rounded,
                          child: Text(
                            'Bạn đã có mặt hôm nay. Đều đặn quan trọng hơn cố quá sức.',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: PrimaryButton(
                    label: 'Về trang chủ',
                    onPressed: () => _home(context, ref),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    ),
  );
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});
  final WeekProgress week;

  @override
  Widget build(BuildContext context) {
    final target = week.targetSessions <= 0 ? 1 : week.targetSessions;
    return AppCard(
      isSelected: week.achieved,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tuần này',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${week.completedSessions}/${week.targetSessions} buổi',
                key: const ValueKey('week-progress'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          WorkoutProgressBar(
            progress: week.completedSessions / target,
            height: 8,
          ),
          if (week.achieved) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.celebration_rounded, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đạt mục tiêu tuần! Streak của bạn được giữ vững.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentLink,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (week.completedSessions < week.targetSessions) ...[
            const SizedBox(height: 8),
            Text(
              'Còn ${week.targetSessions - week.completedSessions} buổi nữa là đạt mục tiêu tuần.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({required this.record});
  final PersonalRecord record;

  @override
  Widget build(BuildContext context) {
    final previous = record.previous;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.trending_up_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.nameVi ?? 'Bài tập',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    previous == null
                        ? record.metricLabelVi
                        : '${record.metricLabelVi} · trước: '
                              '${PersonalRecord.formatValue(record.metric, previous)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              PersonalRecord.formatValue(record.metric, record.value),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement});
  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        isSelected: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(
              Icons.military_tech_rounded,
              color: AppColors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.nameVi,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (achievement.descriptionVi != null)
                    Text(
                      achievement.descriptionVi!,
                      style: const TextStyle(
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
    );
  }
}
