import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../domain/models/workout_session_state.dart';
import '../controllers/workout_controller.dart';
import '../widgets/swap_exercise_sheet.dart';
import '../widgets/workout_widgets.dart';

/// Tổng quan buổi tập: danh sách bài với số hiệp/lần, nút "Bắt đầu".
/// [sessionId] null thì lấy buổi kế tiếp trong kế hoạch.
class WorkoutStartScreen extends ConsumerStatefulWidget {
  const WorkoutStartScreen({super.key, this.sessionId, this.quick5 = false});

  final String? sessionId;
  final bool quick5;

  @override
  ConsumerState<WorkoutStartScreen> createState() => _WorkoutStartScreenState();
}

class _WorkoutStartScreenState extends ConsumerState<WorkoutStartScreen> {
  bool _hasCheckedResume = false;

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _checkResume(WorkoutSetup setup) async {
    if (!mounted) return;

    // 1. Nếu activeWorkoutProvider đang giữ buổi chưa xong của CÙNG session.id -> vào thẳng màn đang tập
    final active = ref.read(activeWorkoutProvider);
    if (active != null &&
        active.endedAt == null &&
        isSameWorkoutSession(active.session.id, setup.session.id)) {
      context.pushReplacement('/workout/active');
      return;
    }

    // 2. Đọc getActiveDraft()
    final repo = ref.read(workoutDraftRepositoryProvider);
    final now = ref.read(workoutClockProvider)();
    final draft = await repo.getActiveDraft();
    if (!mounted || draft == null || !draft.isActive || draft.isExpired(now)) {
      return;
    }

    // Nếu nháp của cùng session.id và còn hiệp chưa xong
    if (isSameWorkoutSession(draft.sessionId, setup.session.id)) {
      WorkoutSessionState draftState;
      try {
        draftState = draft.sessionState;
      } catch (_) {
        return;
      }

      final totalSets = draftState.totalSets;
      final completedSets = draftState.completedSets;
      final hasUnfinished =
          completedSets < totalSets &&
          !draftState.allExercisesDone &&
          draftState.endedAt == null;

      if (!hasUnfinished) return;

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

      if (!mounted) return;

      if (resume == true) {
        ref.read(activeWorkoutProvider.notifier).restore(draftState);
        context.pushReplacement('/workout/active');
      } else if (resume == false) {
        await repo.deleteDraft(draft.clientId);
        if (!mounted) return;
        ref.read(activeWorkoutProvider.notifier).discard(draft.clientId);
        ref.read(activeWorkoutProvider.notifier).start(setup);
        context.pushReplacement('/workout/active');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = (sessionId: widget.sessionId, quick5: widget.quick5);
    final setupAsync = ref.watch(workoutSetupProvider(args));

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: setupAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) {
              if (error is NoOpenSessionTodayException) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    context.pushReplacement('/workout/extra');
                  }
                });
                return const Center(child: CircularProgressIndicator());
              }
              return _ErrorView(
                error: error,
                onRetry: () => ref.invalidate(workoutSetupProvider(args)),
                onClose: () => _close(context),
              );
            },
            data: (setup) {
              if (!_hasCheckedResume) {
                _hasCheckedResume = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkResume(setup);
                });
              }
              return _Overview(
                setup: setup,
                args: args,
                onClose: () => _close(context),
                onStart: () async {
                  final repo = ref.read(workoutDraftRepositoryProvider);
                  final activeDraft = await repo.getActiveDraft();
                  if (activeDraft != null && activeDraft.isActive) {
                    if (!isSameWorkoutSession(
                      activeDraft.sessionId,
                      setup.session.id,
                    )) {
                      await repo.deleteDraft(activeDraft.clientId);
                    }
                  }
                  ref.read(activeWorkoutProvider.notifier).start(setup);
                  if (context.mounted) {
                    context.pushReplacement('/workout/active');
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({
    required this.setup,
    required this.args,
    required this.onClose,
    required this.onStart,
  });

  final WorkoutSetup setup;
  final WorkoutSetupArgs args;
  final VoidCallback onClose;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = setup.session;
    final isExtra = session.id.startsWith('extra-');
    // Hôm nay theo máy chủ (/me.localDate), không theo giờ điện thoại; buổi của ngày khác là tập thêm
    final today =
        ref.watch(userStatusFutureProvider).valueOrNull?.localDate ??
        localDateString(ref.read(workoutClockProvider)());
    final isFuture = !isExtra && session.scheduledDate != today;
    final done = !isExtra && session.status == 'completed';
    // Buổi đã qua bị chốt bỏ (skipped) hoặc nghỉ: không ghi vào lịch được nữa
    final closed = !isExtra && !done && !isSessionOpen(session);
    final shouldOpenExtra = done || isFuture || closed;
    // Backend chỉ đổi bài cho buổi còn planned; buổi tập thêm đổi ngay trên máy
    final canSwap = isExtra || session.status == 'planned';

    final meta = [
      if (session.durationMin > 0) '${session.durationMin} phút',
      '${setup.items.length} động tác',
      if (session.variant == 'quick5') 'Bản 5 phút',
    ].join(' · ');

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              WorkoutHeader(
                title: session.title.isEmpty
                    ? 'Buổi tập hôm nay'
                    : session.title,
                subtitle: meta,
                onClose: onClose,
              ),
              const SizedBox(height: 18),
              if (done) ...[
                const TipBox(
                  icon: Icons.check_circle_rounded,
                  child: Text(
                    'Bạn đã hoàn thành buổi này. Bạn có thể chọn tập thêm.',
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (closed) ...[
                const TipBox(
                  icon: Icons.event_busy_rounded,
                  child: Text(
                    'Buổi này đã qua và được tính là bỏ. Bạn có thể chọn tập thêm.',
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (isFuture) ...[
                const TipBox(
                  icon: Icons.calendar_today_rounded,
                  child: Text(
                    'Buổi này có lịch vào ngày khác. Hôm nay bạn chọn Tập thêm, từ 5 phút vẫn được tính vào chỉ tiêu tuần.',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < setup.items.length; i++) ...[
                _ExerciseRow(
                  index: i + 1,
                  item: setup.items[i],
                  onSwap: !canSwap
                      ? null
                      : () {
                          showSwapExerciseSheet(
                            context: context,
                            sessionId: session.id,
                            item: setup.items[i],
                            currentItems: setup.items,
                            isExtra: isExtra,
                            onSwap: (newItem, alt) {
                              if (isExtra) {
                                final currentExtra = ref.read(
                                  extraWorkoutSetupProvider,
                                );
                                if (currentExtra != null) {
                                  final newItems = currentExtra.items.map((it) {
                                    return it.exerciseId ==
                                            setup.items[i].exerciseId
                                        ? newItem
                                        : it;
                                  }).toList();
                                  final newSessionItems = currentExtra
                                      .session
                                      .items
                                      .map((it) {
                                        return it.exerciseId ==
                                                setup.items[i].exerciseId
                                            ? ItemView(
                                                exerciseId: newItem.exerciseId,
                                                nameVi: newItem.nameVi,
                                                sets: newItem.sets,
                                                reps: newItem.reps,
                                                durationSec:
                                                    newItem.durationSec,
                                                restSec: newItem.restSec,
                                              )
                                            : it;
                                      })
                                      .toList();
                                  final newSession = SessionView(
                                    id: currentExtra.session.id,
                                    scheduledDate:
                                        currentExtra.session.scheduledDate,
                                    scheduledTime:
                                        currentExtra.session.scheduledTime,
                                    title: currentExtra.session.title,
                                    durationMin:
                                        currentExtra.session.durationMin,
                                    variant: currentExtra.session.variant,
                                    status: currentExtra.session.status,
                                    items: newSessionItems,
                                  );
                                  ref
                                      .read(extraWorkoutSetupProvider.notifier)
                                      .state = WorkoutSetup(
                                    session: newSession,
                                    items: newItems,
                                  );
                                }
                              }
                              ref.invalidate(workoutSetupProvider(args));
                            },
                          );
                        },
                ),
                const SizedBox(height: 10),
              ],
              if (setup.items.isEmpty)
                const Text(
                  'Buổi này chưa có bài tập.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Semantics(
            label: shouldOpenExtra
                ? 'Mở danh sách bài tập thêm'
                : 'Bắt đầu buổi tập',
            button: true,
            child: PrimaryButton(
              label: shouldOpenExtra ? 'Tập thêm' : 'Bắt đầu',
              icon: Icon(
                shouldOpenExtra ? Icons.add_rounded : Icons.play_arrow_rounded,
                color: AppColors.surface,
              ),
              onPressed: setup.items.isEmpty
                  ? null
                  : (shouldOpenExtra
                        ? () => context.push('/workout/extra')
                        : onStart),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.index,
    required this.item,
    required this.onSwap,
  });

  final int index;
  final WorkoutPlanItem item;

  /// null: buổi không đổi bài được nữa, ẩn nút "Đổi".
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    final hasCamera = item.exercise?.camera != null;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 44,
              height: 44,
              child: ExerciseImage(
                slug: item.exercise?.slug ?? item.exerciseId,
                thumbnailUrl: item.exercise?.thumbnailUrl,
                width: 44,
                height: 44,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$index',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.nameVi,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    item.targetLabel,
                    if (item.restSec > 0) 'nghỉ ${item.restSec}s',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (hasCamera) ...[
            const Tooltip(
              message: 'Đếm được bằng camera',
              child: Icon(
                Icons.videocam_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (onSwap != null)
            TextButton.icon(
              key: ValueKey('swap-btn-${item.exerciseId}'),
              onPressed: onSwap,
              icon: const Icon(
                Icons.swap_horiz_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text(
                'Đổi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.error,
    required this.onRetry,
    required this.onClose,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final api = error is ApiException ? error as ApiException : null;
    final message = api?.isNetworkError == true
        ? 'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'
        : api?.code == 'SESSION_NOT_FOUND'
        ? 'Không tìm thấy buổi tập trong kế hoạch tuần này.'
        : 'Không tải được buổi tập (${api?.statusCode ?? api?.code ?? 'lỗi'}).';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: WorkoutIconButton(
              icon: Icons.close_rounded,
              onTap: onClose,
              tooltip: 'Thoát',
            ),
          ),
          const Spacer(),
          ErrorBanner(message: message),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Thử lại', onPressed: onRetry),
          const Spacer(),
        ],
      ),
    );
  }
}
