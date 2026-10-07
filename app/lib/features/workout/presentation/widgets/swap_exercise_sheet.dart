import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/api/api_exceptions.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/error_messages.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../coach/presentation/controllers/coach_controller.dart';
import '../../../home/presentation/controllers/home_controller.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
import '../../domain/models/exercise_alternative.dart';
import '../../domain/models/exercise_response.dart';
import '../../domain/models/workout_session_state.dart';
import '../controllers/workout_controller.dart';
import 'workout_widgets.dart';

/// Hiển thị bottom sheet "Đổi bài [tên]".
Future<void> showSwapExerciseSheet({
  required BuildContext context,
  required String sessionId,
  required WorkoutPlanItem item,
  required List<WorkoutPlanItem> currentItems,
  required bool isExtra,
  required void Function(WorkoutPlanItem newItem, ExerciseAlternative alt)
  onSwap,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SwapExerciseSheet(
      sessionId: sessionId,
      item: item,
      currentItems: currentItems,
      isExtra: isExtra,
      onSwap: onSwap,
    ),
  );
}

class SwapExerciseSheet extends ConsumerStatefulWidget {
  const SwapExerciseSheet({
    super.key,
    required this.sessionId,
    required this.item,
    required this.currentItems,
    required this.isExtra,
    required this.onSwap,
  });

  final String sessionId;
  final WorkoutPlanItem item;
  final List<WorkoutPlanItem> currentItems;
  final bool isExtra;
  final void Function(WorkoutPlanItem newItem, ExerciseAlternative alt) onSwap;

  @override
  ConsumerState<SwapExerciseSheet> createState() => _SwapExerciseSheetState();
}

class _SwapExerciseSheetState extends ConsumerState<SwapExerciseSheet> {
  bool _loading = true;
  Object? _error;
  List<ExerciseAlternative> _alternatives = [];
  List<ExerciseResponse> _allExercises = [];
  bool _remember = false;
  bool _isSwapping = false;

  @override
  void initState() {
    super.initState();
    _loadAlternatives();
  }

  Future<void> _loadAlternatives() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(workoutRepositoryProvider);
      if (widget.isExtra) {
        final exercises = await repo.getExercises();
        _allExercises = exercises;
        final existingIds = widget.currentItems
            .map((i) => i.exerciseId)
            .toSet();
        final available = exercises
            .where((e) => e.isActive && !existingIds.contains(e.id))
            .toList();

        final currentMuscle =
            widget.item.exercise?.primaryMuscle ??
            exercises
                .where((e) => e.id == widget.item.exerciseId)
                .firstOrNull
                ?.primaryMuscle;

        available.sort((a, b) {
          final aSame =
              a.primaryMuscle != null && a.primaryMuscle == currentMuscle;
          final bSame =
              b.primaryMuscle != null && b.primaryMuscle == currentMuscle;
          if (aSame && !bSame) return -1;
          if (!aSame && bSame) return 1;
          return a.nameVi.compareTo(b.nameVi);
        });

        _alternatives = available
            .map(
              (e) => ExerciseAlternative(
                exerciseId: e.id,
                nameVi: e.nameVi,
                slug: e.slug,
                thumbnailUrl: e.thumbnailUrl,
                primaryMuscle: e.primaryMuscle,
                tracking: e.tracking,
                cameraSupported: e.camera != null,
                reason:
                    (e.primaryMuscle != null &&
                        e.primaryMuscle == currentMuscle)
                    ? 'Cùng nhóm cơ'
                    : null,
              ),
            )
            .toList();
      } else {
        _alternatives = await repo.getAlternatives(
          sessionId: widget.sessionId,
          exerciseId: widget.item.exerciseId,
        );
      }
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _onSelectAlternative(ExerciseAlternative alt) async {
    if (_isSwapping) return;
    setState(() => _isSwapping = true);

    if (widget.isExtra) {
      final exercises = _allExercises.isNotEmpty
          ? _allExercises
          : await ref.read(workoutRepositoryProvider).getExercises();
      final newExercise =
          exercises.where((e) => e.id == alt.exerciseId).firstOrNull ??
          ExerciseResponse(
            id: alt.exerciseId,
            slug: alt.slug ?? alt.exerciseId,
            nameVi: alt.nameVi,
            primaryMuscle: alt.primaryMuscle,
            tracking: alt.tracking,
          );
      final isDuration = (newExercise.tracking ?? alt.tracking) == 'duration';
      final newItem = WorkoutPlanItem(
        exerciseId: alt.exerciseId,
        nameVi: alt.nameVi,
        sets: widget.item.sets,
        reps: isDuration ? null : (widget.item.reps ?? 10),
        durationSec: isDuration ? (widget.item.durationSec ?? 30) : null,
        restSec: widget.item.restSec,
        exercise: newExercise,
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onSwap(newItem, alt);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã đổi ${widget.item.nameVi} → ${alt.nameVi}'),
          ),
        );
      }
      return;
    }

    try {
      await ref
          .read(workoutRepositoryProvider)
          .swapExercise(
            sessionId: widget.sessionId,
            fromExerciseId: widget.item.exerciseId,
            toExerciseId: alt.exerciseId,
            remember: _remember,
          );

      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      ref.invalidate(homePlanProvider);
      ref.invalidate(weeklyPlanFutureProvider);

      ExerciseResponse? newExercise;
      try {
        final exercises = await ref
            .read(workoutRepositoryProvider)
            .getExercises();
        newExercise = exercises
            .where((e) => e.id == alt.exerciseId)
            .firstOrNull;
      } catch (_) {}

      final isDuration = (newExercise?.tracking ?? alt.tracking) == 'duration';
      final newItem = WorkoutPlanItem(
        exerciseId: alt.exerciseId,
        nameVi: alt.nameVi,
        sets: widget.item.sets,
        reps: isDuration ? null : (widget.item.reps ?? 10),
        durationSec: isDuration ? (widget.item.durationSec ?? 30) : null,
        restSec: widget.item.restSec,
        exercise: newExercise,
      );

      widget.onSwap(newItem, alt);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã đổi ${widget.item.nameVi} → ${alt.nameVi}')),
      );
    } catch (e) {
      if (!mounted) return;
      final isNotPlanned =
          (e is ApiException &&
          (e.statusCode == 409 || e.code == 'SESSION_NOT_PLANNED'));
      final message = isNotPlanned
          ? 'Buổi này đã tập hoặc đã bỏ, không đổi được nữa'
          : mapErrorMessage(e);

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isNotPlanned ? const Color(0xFFDC2626) : null,
        ),
      );
    }
  }

  void _onAskCoach() {
    Navigator.of(context).pop();
    ref.read(coachDraftMessageProvider.notifier).state =
        'Mình không thích bài ${widget.item.nameVi}, gợi ý bài khác cùng nhóm cơ giúp mình';
    context.go('/coach');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Đổi bài ${widget.item.nameVi}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  WorkoutIconButton(
                    icon: Icons.close_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    tooltip: 'Đóng',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loading)
                        _buildSkeleton()
                      else if (_error != null)
                        _buildError()
                      else if (_alternatives.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'Chưa có bài thay thế phù hợp',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        for (final alt in _alternatives) ...[
                          _AlternativeCard(
                            alt: alt,
                            enabled: !_isSwapping,
                            onTap: () => _onSelectAlternative(alt),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                      if (!widget.isExtra) ...[
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: _isSwapping
                              ? null
                              : () => setState(() => _remember = !_remember),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _remember,
                                  onChanged: _isSwapping
                                      ? null
                                      : (val) => setState(
                                          () => _remember = val ?? false,
                                        ),
                                ),
                                const Expanded(
                                  child: Text(
                                    'Không gợi ý bài này nữa',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('ask-coach-btn'),
                onPressed: _onAskCoach,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Hỏi coach gợi ý thêm'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Column(
      key: const ValueKey('swap-skeleton'),
      children: List.generate(
        3,
        (index) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 140,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 200,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
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

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          ErrorBanner(message: mapErrorMessage(_error)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadAlternatives,
            child: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({
    required this.alt,
    required this.enabled,
    required this.onTap,
  });

  final ExerciseAlternative alt;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 44,
                height: 44,
                child: ExerciseImage(
                  slug: alt.slug ?? alt.exerciseId,
                  thumbnailUrl: alt.thumbnailUrl,
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
                      Expanded(
                        child: Text(
                          alt.nameVi,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (alt.cameraSupported) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Camera',
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
                  if (alt.reason != null && alt.reason!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      alt.reason!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
