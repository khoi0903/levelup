import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/models/workout_session_state.dart';
import '../controllers/workout_controller.dart';
import '../widgets/workout_widgets.dart';

/// Tổng quan buổi tập: danh sách bài với số hiệp/lần, nút "Bắt đầu".
/// [sessionId] null thì lấy buổi kế tiếp trong kế hoạch.
class WorkoutStartScreen extends ConsumerWidget {
  const WorkoutStartScreen({super.key, this.sessionId, this.quick5 = false});

  final String? sessionId;
  final bool quick5;

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = (sessionId: sessionId, quick5: quick5);
    final setupAsync = ref.watch(workoutSetupProvider(args));

    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: setupAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _ErrorView(
              error: error,
              onRetry: () => ref.invalidate(workoutSetupProvider(args)),
              onClose: () => _close(context),
            ),
            data: (setup) => _Overview(
              setup: setup,
              onClose: () => _close(context),
              onStart: () {
                ref.read(activeWorkoutProvider.notifier).start(setup);
                context.pushReplacement('/workout/active');
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({
    required this.setup,
    required this.onClose,
    required this.onStart,
  });

  final WorkoutSetup setup;
  final VoidCallback onClose;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final session = setup.session;
    final done = session.status == 'completed';
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
                    'Bạn đã hoàn thành buổi này. Tập thêm vẫn được ghi lại.',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              for (var i = 0; i < setup.items.length; i++) ...[
                _ExerciseRow(index: i + 1, item: setup.items[i]),
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
          child: PrimaryButton(
            label: 'Bắt đầu',
            icon: const Icon(
              Icons.play_arrow_rounded,
              color: AppColors.surface,
            ),
            onPressed: setup.items.isEmpty ? null : onStart,
          ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.index, required this.item});

  final int index;
  final WorkoutPlanItem item;

  @override
  Widget build(BuildContext context) {
    final hasCamera = item.exercise?.camera != null;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nameVi,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
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
          if (hasCamera)
            const Tooltip(
              message: 'Đếm được bằng camera',
              child: Icon(
                Icons.videocam_outlined,
                size: 20,
                color: AppColors.primary,
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
