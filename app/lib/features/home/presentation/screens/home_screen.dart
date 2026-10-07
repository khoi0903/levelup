import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../../buddies/presentation/controllers/buddy_controller.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../../streak/presentation/controllers/streak_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../../workout/domain/models/workout_draft.dart';
import '../../../workout/presentation/controllers/workout_controller.dart';
import '../../../workout/domain/models/workout_session_state.dart';
import '../controllers/home_controller.dart';

/// Màn hình Trang chủ (Home) - hoàn toàn kết nối API, bỏ dữ liệu giả.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final List<DateTime> _tapTimestamps = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      triggerSyncPendingWorkoutDrafts(ref);
    });
  }

  void _handleHeaderTap() {
    final now = DateTime.now();
    _tapTimestamps.removeWhere((t) => now.difference(t).inMilliseconds > 3000);
    _tapTimestamps.add(now);

    if (_tapTimestamps.length >= 5) {
      _tapTimestamps.clear();
      context.push('/demo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userStatusFutureProvider);
    final planAsync = ref.watch(homePlanProvider);
    final streakAsync = ref.watch(streakFutureProvider);
    final buddyAsync = ref.watch(buddyTodayFutureProvider);
    final activeDraftAsync = ref.watch(activeWorkoutDraftProvider);

    // Khi đang tải dữ liệu ban đầu, hiển thị Skeleton
    if (userAsync.isLoading || planAsync.isLoading) {
      return const Scaffold(
        body: GradientBackground(child: SafeArea(child: HomeScreenSkeleton())),
      );
    }

    if (userAsync.hasError && userAsync.valueOrNull == null) {
      return Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: ErrorView(
              message: mapErrorMessage(userAsync.error),
              onRetry: () => ref.invalidate(userStatusFutureProvider),
            ),
          ),
        ),
      );
    }

    final me = userAsync.valueOrNull;
    final displayName = me?.displayName ?? '';
    final streakWeeks =
        streakAsync.valueOrNull?.currentWeeks ?? me?.streak?.currentWeeks ?? 0;
    final dateText = me?.localDate ?? _currentDateString();

    final plan = planAsync.valueOrNull;
    final todayStr = localDateString(DateTime.now());
    final todaySession = plan == null ? null : pickNextSession(plan, todayStr);
    // Đã tập xong, không có buổi hôm nay, hoặc buổi kế tiếp ở ngày sau: tập lúc này là "Tập thêm"
    final todayDone =
        todaySession == null ||
        todaySession.status == 'completed' ||
        !canLinkToPlan(todaySession.scheduledDate, DateTime.now());

    final totalTarget =
        streakAsync.valueOrNull?.thisWeek?.targetSessions ??
        plan?.targetSessions ??
        0;
    final currentSessionsCount =
        streakAsync.valueOrNull?.thisWeek?.completedSessions ??
        (plan == null
            ? 0
            : plan.sessions.where((s) => s.status == 'completed').length);

    final buddy = buddyAsync.valueOrNull;

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              await triggerSyncPendingWorkoutDrafts(ref);
              ref.invalidate(userStatusFutureProvider);
              ref.invalidate(homePlanProvider);
              ref.invalidate(streakFutureProvider);
              ref.invalidate(buddyTodayFutureProvider);
              ref.invalidate(activeWorkoutDraftProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header: Greeting + Streak badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          key: const ValueKey('home-header-title-tap'),
                          behavior: HitTestBehavior.opaque,
                          onTap: _handleHeaderTap,
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
                                key: const ValueKey('home-greeting-text'),
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => context.push('/streak'),
                        borderRadius: BorderRadius.circular(
                          AppColors.radiusPill,
                        ),
                        child: Container(
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
                                key: const ValueKey('home-streak-badge'),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accentLink,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Card tập dở (nếu có draft active < 12h)
                  if (activeDraftAsync.valueOrNull != null) ...[
                    _buildActiveDraftCard(
                      context,
                      activeDraftAsync.valueOrNull!,
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Card Check-in sáng
                  _buildCheckinCard(context),
                  const SizedBox(height: 14),

                  // Card Tuần này
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
                              key: const ValueKey('home-week-sessions'),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildWeekDaysRow(plan, me?.weekStart),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Card Buổi tập chính hôm nay
                  _buildTodayWorkoutCard(
                    context,
                    ref,
                    todaySession,
                    todayDone,
                    todayStr,
                  ),
                  const SizedBox(height: 14),

                  // Card Buddy feed
                  _buildBuddyCard(context, ref, buddy),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveDraftCard(BuildContext context, WorkoutDraft draft) {
    WorkoutSessionState state;
    try {
      state = draft.sessionState;
    } catch (_) {
      return const SizedBox.shrink();
    }
    final sessionTitle = state.session.title;
    return Container(
      key: const ValueKey('home-active-draft-card'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_circle_outline_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bạn đang tập dở $sessionTitle',
                  key: const ValueKey('home-active-draft-title'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Hiệp ${state.setNumber} · ${state.currentItem?.nameVi ?? 'Bài tập'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const ValueKey('home-active-draft-discard-button'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () async {
              await ref
                  .read(workoutDraftRepositoryProvider)
                  .deleteDraft(draft.clientId);
              ref.read(activeWorkoutProvider.notifier).clear();
              ref.invalidate(activeWorkoutDraftProvider);
            },
            child: const Text(
              'Bỏ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 6),
          FilledButton(
            key: const ValueKey('home-active-draft-continue-button'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              ref.read(activeWorkoutProvider.notifier).restore(state);
              context.push('/workout/active');
            },
            child: const Text(
              'Tiếp tục',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckinCard(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/checkin'),
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wb_sunny_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check-in năng lượng hôm nay',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Để coach điều chỉnh khối lượng tập phù hợp',
                    style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF2563EB)),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayWorkoutCard(
    BuildContext context,
    WidgetRef ref,
    SessionView? todaySession,
    bool todayDone,
    String todayStr,
  ) {
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final activeDraft = ref.watch(activeWorkoutDraftProvider).valueOrNull;
    final now = ref.watch(workoutClockProvider)();

    final hasIncompleteWorkout = todaySession != null &&
        (
          (activeWorkout != null &&
              activeWorkout.endedAt == null &&
              isSameWorkoutSession(activeWorkout.session.id, todaySession.id)) ||
          (activeDraft != null &&
              activeDraft.isActive &&
              !activeDraft.isExpired(now) &&
              isSameWorkoutSession(activeDraft.sessionId, todaySession.id) &&
              activeDraft.hasUnfinishedSets)
        );

    return GlassCard(
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
              border: Border.all(color: AppColors.border, width: 1.0),
            ),
            child: const Center(
              child: Icon(
                Icons.fitness_center_rounded,
                size: 38,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            todaySession != null && todaySession.scheduledTime.isNotEmpty
                ? '${_sessionDayLabel(todaySession.scheduledDate)} · ${todaySession.scheduledTime}'
                : AppStrings.todayWorkoutHeader,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.accentLink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            todaySession?.title ?? AppStrings.todayWorkoutTitle,
            key: const ValueKey('home-today-workout-title'),
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
          if (todaySession != null && todaySession.items.isNotEmpty) ...[
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
          if (todaySession?.adjustedReason != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.0),
              ),
              child: Text(
                _formatAdjustedReason(todaySession!.adjustedReason!),
                key: const ValueKey('home-adjusted-reason-text'),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: todayDone
                      ? 'Tập thêm'
                      : (hasIncompleteWorkout
                          ? 'Tiếp tục buổi tập'
                          : AppStrings.btnStart),
                  height: 48,
                  onPressed: todayDone
                      ? () => context.push('/workout/extra')
                      : () => _handleStartWorkout(
                          context,
                          ref,
                          todaySession!,
                          quick5: false,
                        ),
                ),
              ),
              const SizedBox(width: 8),
              SecondaryButton(
                label: AppStrings.btnOnly5Min,
                height: 48,
                onPressed: todayDone
                    ? null
                    : () => _handleStartWorkout(
                        context,
                        ref,
                        todaySession,
                        quick5: true,
                      ),
              ),
            ],
          ),
          if (todaySession != null &&
              todaySession.scheduledDate == todayStr &&
              todaySession.status == 'planned') ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: () => context.push(
                  '/skip-report?sessionId=${todaySession.id}',
                ),
                child: const Text(
                  'Không tập được hôm nay?',
                  key: ValueKey('home-skip-report-button'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleStartWorkout(
    BuildContext context,
    WidgetRef ref,
    SessionView? session, {
    bool quick5 = false,
  }) async {
    final targetId = session?.id ?? '';

    // 1. Nếu activeWorkoutProvider đang giữ buổi chưa xong của CÙNG session.id -> vào thẳng màn đang tập
    final active = ref.read(activeWorkoutProvider);
    if (active != null &&
        active.endedAt == null &&
        targetId.isNotEmpty &&
        isSameWorkoutSession(active.session.id, targetId)) {
      context.push('/workout/active');
      return;
    }

    // 2. Đọc getActiveDraft(): còn hạn, cùng session.id và còn hiệp chưa xong
    final repo = ref.read(workoutDraftRepositoryProvider);
    final now = ref.read(workoutClockProvider)();
    final draft = await repo.getActiveDraft();
    if (!context.mounted) return;

    if (draft != null &&
        draft.isActive &&
        !draft.isExpired(now) &&
        targetId.isNotEmpty &&
        isSameWorkoutSession(draft.sessionId, targetId) &&
        draft.hasUnfinishedSets) {
      WorkoutSessionState draftState;
      try {
        draftState = draft.sessionState;
      } catch (_) {
        if (!context.mounted) return;
        _navigateToStart(context, session, quick5);
        return;
      }

      final totalSets = draftState.totalSets;
      final completedSets = draftState.completedSets;

      if (!context.mounted) return;
      final resume = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Buổi tập đang dở'),
          content: Text(
            'Bạn đang tập dở buổi này (đã xong $completedSets/$totalSets hiệp). Tiếp tục?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Tập lại từ đầu'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Tiếp tục'),
            ),
          ],
        ),
      );

      if (!context.mounted) return;

      if (resume == true) {
        ref.read(activeWorkoutProvider.notifier).restore(draftState);
        context.push('/workout/active');
        return;
      } else if (resume == false) {
        await repo.deleteDraft(draft.clientId);
        if (!context.mounted) return;
        ref.read(activeWorkoutProvider.notifier).discard(draft.clientId);
        ref.invalidate(activeWorkoutDraftProvider);
        _navigateToStart(context, session, quick5);
        return;
      } else {
        return;
      }
    } else if (draft != null && draft.isActive) {
      // Nháp của buổi KHÁC: không hỏi, xoá nháp cũ khi bắt đầu buổi mới
      if (targetId.isNotEmpty &&
          !isSameWorkoutSession(draft.sessionId, targetId)) {
        await repo.deleteDraft(draft.clientId);
        ref.invalidate(activeWorkoutDraftProvider);
      }
    }

    if (!context.mounted) return;
    _navigateToStart(context, session, quick5);
  }

  void _navigateToStart(
    BuildContext context,
    SessionView? session,
    bool quick5,
  ) {
    if (session == null) {
      context.push(quick5 ? '/workout?quick5=true' : '/workout');
    } else {
      context.push(
        quick5
            ? '/workout/${session.id}?quick5=true'
            : '/workout/${session.id}',
      );
    }
  }

  Widget _buildBuddyCard(
    BuildContext context,
    WidgetRef ref,
    dynamic buddyToday,
  ) {
    if (buddyToday != null) {
      final buddy = buddyToday.buddy;
      final actions = buddyToday.myActionsToday;

      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        borderRadius: AppColors.radiusCard,
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryLight,
                border: Border.all(color: AppColors.border, width: 1.0),
              ),
              child: const Icon(
                Icons.person,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${buddy.displayName} · Streak ${buddy.streakWeeks} tuần',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    buddy.isDone
                        ? 'Đã hoàn thành buổi hôm nay!'
                        : (buddy.isPlanned
                              ? 'Dự kiến tập lúc ${buddy.scheduledTime ?? "hôm nay"}'
                              : 'Nghỉ hôm nay'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: actions.cheered
                  ? null
                  : () {
                      ref
                          .read(buddyControllerProvider.notifier)
                          .sendCheer(buddyToday.pairId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã gửi lời cổ vũ tới ${buddy.displayName}! 🔥',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
              borderRadius: BorderRadius.circular(AppColors.radiusPill),
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: actions.cheered
                      ? AppColors.accentLink
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.btnShadow,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Text(
                  actions.cheered ? 'Đã cổ vũ' : AppStrings.btnCheer,
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
      );
    }

    // Khi chưa có buddy, hiển thị card gợi ý kết nối
    return InkWell(
      onTap: () => context.push('/buddy'),
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: AppColors.radiusCard,
        child: Row(
          children: [
            const Icon(
              Icons.people_outline_rounded,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tập cùng bạn đồng hành',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Mời bạn bè để cùng nhắc nhở và giữ thói quen lâu hơn.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDaysRow(PlanView? plan, String? weekStart) {
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1 = Mon .. 7 = Sun
    final labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        final dayIndex = i + 1; // 1..7
        final isToday = dayIndex == todayWeekday;

        // Tìm session tương ứng với ngày trong tuần
        final session = plan?.sessions.firstWhere(
          (s) {
            final dt = DateTime.tryParse(s.scheduledDate);
            return dt != null && dt.weekday == dayIndex;
          },
          orElse: () => const SessionView(
            id: '',
            scheduledDate: '',
            scheduledTime: '',
            title: '',
            durationMin: 0,
          ),
        );

        final isCompleted = session?.status == 'completed';

        _DayStatus status;
        if (isCompleted) {
          status = _DayStatus.completed;
        } else if (isToday) {
          status = _DayStatus.today;
        } else {
          status = _DayStatus.pending;
        }

        return _WeekDayDot(label: labels[i], status: status);
      }),
    );
  }

  String _formatAdjustedReason(String reason) {
    switch (reason) {
      case 'checkin_tired':
        return 'Coach: Sáng nay bạn chọn "Mệt mỏi", nên mình đã giảm bớt khối lượng buổi tập.';
      case 'skip_busy':
        return 'Coach: Đã rút ngắn bài tập phù hợp với thời gian bận rộn của bạn.';
      case 'skip_pain':
        return 'Coach: Đã thay thế các động tác an toàn cho vùng đau.';
      case 'user_reschedule':
        return 'Buổi tập đã được dời lịch theo yêu cầu của bạn.';
      case 'user_quick5':
        return 'Buổi tập rút gọn 5 phút.';
      case 'coach_action':
        return 'Buổi tập đã được điều chỉnh theo hướng dẫn của AI Coach.';
      default:
        return 'Coach: Buổi tập hôm nay đã được điều chỉnh phù hợp ($reason).';
    }
  }

  String _currentDateString() {
    final now = DateTime.now();
    final days = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    return '${days[now.weekday - 1]}, ${now.day}/${now.month}';
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
                : AppColors.surface,
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

/// "Hôm nay", "Ngày mai" hoặc thứ trong tuần của buổi kế tiếp.
String _sessionDayLabel(String scheduledDate) {
  final d = DateTime.tryParse(scheduledDate);
  if (d == null) return 'Hôm nay';
  final now = DateTime.now();
  final diff = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (diff <= 0) return 'Hôm nay';
  if (diff == 1) return 'Ngày mai';
  const names = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ nhật',
  ];
  return names[d.weekday - 1];
}
