import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_palette.dart';
import '../../../../core/review/review_prompt.dart';
import '../../../../core/voice/voice_models.dart';
import '../../../../core/voice/voice_provider.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../streak/presentation/controllers/streak_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/models/workout_models.dart';
import '../controllers/workout_controller.dart';
import '../widgets/workout_widgets.dart';

/// Màn Kết quả (F2): thời lượng, streak, tiến độ tuần, kỷ lục, huy hiệu.
class WorkoutResultScreen extends ConsumerStatefulWidget {
  const WorkoutResultScreen({super.key});

  @override
  ConsumerState<WorkoutResultScreen> createState() =>
      _WorkoutResultScreenState();
}

class _WorkoutResultScreenState extends ConsumerState<WorkoutResultScreen> {
  bool _hasAnnounced = false;
  Timer? _prTimer;
  Timer? _reviewTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceResult();
      _scheduleReviewPrompt();
    });
  }

  @override
  void dispose() {
    _prTimer?.cancel();
    _reviewTimer?.cancel();
    super.dispose();
  }

  /// Mời đánh giá trên Google Play sau khi màn chúc mừng đã hiện xong
  /// (buổi được tính thứ 3 hoặc lần đầu đạt mục tiêu tuần, tối đa một lần).
  /// Chạy nền, không chặn điều hướng.
  void _scheduleReviewPrompt() {
    final result = ref.read(activeWorkoutProvider)?.result;
    if (result == null) return;
    final prompt = ref.read(reviewPromptProvider);
    _reviewTimer = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      unawaited(
        prompt.onWorkoutFinished(
          countsForStreak: result.countsForStreak,
          duplicate: result.duplicate,
          weekCompleted: result.week?.completedSessions,
          weekTarget: result.week?.targetSessions,
          weekAchieved: result.week?.achieved ?? false,
        ),
      );
    });
  }

  void _announceResult() {
    if (_hasAnnounced) return;
    _hasAnnounced = true;

    final activeSession = ref.read(activeWorkoutProvider);
    final result = activeSession?.result;
    if (result == null) return;

    final coach = ref.read(voiceCoachProvider);
    final minutes = (result.durationSec / 60).ceil();
    final params = <String, Object?>{
      'minutes': minutes > 0 ? '$minutes' : '1',
      if (result.kcalBurned > 0) 'kcal': '${result.kcalBurned}',
    };

    coach.speakLine(VoiceLineKey.workoutDone, params: params);

    if (result.personalRecords.isNotEmpty) {
      _prTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) coach.speakLine(VoiceLineKey.personalRecord);
      });
    }
  }

  void _home(BuildContext context) {
    // Làm mới Home để buổi vừa tập hiện là đã xong.
    ref.invalidate(homePlanProvider);
    ref.invalidate(userStatusFutureProvider);
    ref.invalidate(streakFutureProvider);
    ref.invalidate(streakWeekDetailProvider);
    ref.read(activeWorkoutProvider.notifier).clear();
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final activeSession = ref.watch(activeWorkoutProvider);
    final result = activeSession?.result;
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
    final isExtra =
        activeSession?.isExtra == true ||
        activeSession?.session.id.startsWith('extra-') == true;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _home(context);
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
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 56,
                        color: context.colors.primary,
                      ),
                      const SizedBox(height: 8),
                      if (isExtra) ...[
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: context.colors.primaryLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Buổi tập thêm',
                              key: ValueKey('result-extra-badge'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: context.colors.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                      Text(
                        'Xong buổi tập!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bạn đã tập ${formatDurationVi(result.durationSec)}',
                        key: const ValueKey('result-duration'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.colors.textSecondary,
                        ),
                      ),
                      if (result.kcalBurned > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 20,
                              color: Color(0xFFEA580C),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Đốt khoảng ${result.kcalBurned} kcal',
                              key: const ValueKey('result-kcal-burned'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'ước tính',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      TipBox(
                        icon: result.countsForStreak
                            ? Icons.local_fire_department_rounded
                            : Icons.info_outline_rounded,
                        child: Text(
                          result.countsForStreak
                              ? 'Buổi này được tính vào streak tuần.'
                              : (result.durationSec >= 300
                                    ? 'Buổi tập đã lưu nhưng không tính vào chỉ tiêu tuần vì gửi lên quá 24 giờ sau khi tập'
                                    : 'Buổi dưới 5 phút không tính streak. Lần sau cố thêm chút nữa nhé!'),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: context.colors.warningBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: context.colors.warningBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.celebration_rounded,
                                color: Color(0xFFD97706),
                                size: 28,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Ăn mừng thành tích! Bạn vừa mở khóa huy hiệu mới.',
                                  key: ValueKey(
                                    'achievement-celebration-banner',
                                  ),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: context.colors.warningText,
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
                  child: Column(
                    children: [
                      SecondaryButton(
                        label: 'Tập thêm',
                        icon: Icon(
                          Icons.add_rounded,
                          color: context.colors.primary,
                        ),
                        onPressed: () {
                          ref.invalidate(homePlanProvider);
                          ref.invalidate(userStatusFutureProvider);
                          ref.invalidate(streakFutureProvider);
                          ref.read(activeWorkoutProvider.notifier).clear();
                          context.push('/workout/extra');
                        },
                      ),
                      const SizedBox(height: 10),
                      Semantics(
                        label: 'Về trang chủ',
                        button: true,
                        child: PrimaryButton(
                          label: 'Về trang chủ',
                          onPressed: () => _home(context),
                        ),
                      ),
                    ],
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
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: context.colors.textPrimary,
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
              Expanded(
                child: Text(
                  'Tuần này',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.colors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${week.completedSessions}/${week.targetSessions} buổi',
                key: const ValueKey('week-progress'),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textSecondary,
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
            Row(
              children: [
                Icon(Icons.celebration_rounded, color: context.colors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Đạt mục tiêu tuần! Streak của bạn được giữ vững.',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.colors.accentLink,
                    ),
                  ),
                ),
              ],
            ),
          ] else if (week.completedSessions < week.targetSessions) ...[
            const SizedBox(height: 8),
            Text(
              'Còn ${week.targetSessions - week.completedSessions} buổi nữa là đạt mục tiêu tuần.',
              style: TextStyle(
                fontSize: 13,
                color: context.colors.textSecondary,
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
            Icon(Icons.trending_up_rounded, color: context.colors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.nameVi ?? 'Bài tập',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  Text(
                    previous == null
                        ? record.metricLabelVi
                        : '${record.metricLabelVi} · trước: '
                              '${PersonalRecord.formatValue(record.metric, previous)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              PersonalRecord.formatValue(record.metric, record.value),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.colors.primary,
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
            Icon(
              Icons.military_tech_rounded,
              color: context.colors.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.nameVi,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: context.colors.textPrimary,
                    ),
                  ),
                  if (achievement.descriptionVi != null)
                    Text(
                      achievement.descriptionVi!,
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
    );
  }
}
