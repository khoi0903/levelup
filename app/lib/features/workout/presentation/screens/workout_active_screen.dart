import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../domain/models/workout_models.dart';
import '../../domain/models/workout_session_state.dart';
import '../../../../core/voice/voice_models.dart';
import '../../../../core/voice/voice_provider.dart';
import '../controllers/workout_controller.dart';
import '../widgets/swap_exercise_sheet.dart';
import '../widgets/workout_widgets.dart';
import '../../data/camera/auto_camera_setting.dart';
import 'camera_set_screen.dart';


/// Màn "Đang tập" (Figma: Frame 16): một bài, một hiệp tại một thời điểm,
/// nghỉ giữa hiệp theo restSec, bỏ qua bài.
class WorkoutActiveScreen extends ConsumerStatefulWidget {
  const WorkoutActiveScreen({super.key});

  @override
  ConsumerState<WorkoutActiveScreen> createState() =>
      _WorkoutActiveScreenState();
}

class _WorkoutActiveScreenState extends ConsumerState<WorkoutActiveScreen>
    with WidgetsBindingObserver {
  static const _maxDurationSec = 7200;

  // Khóa của hiệp đang nhập; đổi khóa thì đặt lại ô nhập.
  String? _inputKey;
  int _reps = 10;
  double _weight = 0;
  int _durationSec = 0;
  bool _timerRunning = false;
  Timer? _timer;

  int? _restRemaining;
  Timer? _restTimer;
  Timer? _countdownTimer;

  int? _lastAnnouncedExerciseIndex;

  /// Hiệp đã tự mở camera (exerciseIndex/setNumber): quay lại từ camera thì không mở lại cho hiệp đó.
  String? _autoCameraKey;
  final Set<int> _spokenDurationSeconds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(activeWorkoutProvider);
      final item = s?.currentItem;
      if (s != null && item != null) {
        _announceSetStart(item, s);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(voiceCoachProvider).setAppLifecycle(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _restTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }


  /// Bài đếm được bằng camera và người dùng bật "Tự mở camera khi bắt đầu hiệp".
  bool _autoCameraFor(WorkoutPlanItem item) =>
      ref.read(autoCameraProvider) &&
      ref.read(repSessionFactoryProvider).supports(item.exercise?.camera);

  /// Mở camera cho hiệp hiện tại (một lần mỗi hiệp), sau khung hình hiện tại.
  void _maybeAutoCamera(WorkoutSessionState s, WorkoutPlanItem item) {
    if (_restRemaining != null || !_autoCameraFor(item)) return;
    final key = '${s.exerciseIndex}/${s.setNumber}/${item.exerciseId}';
    if (_autoCameraKey == key) return;
    _autoCameraKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final current = ref.read(activeWorkoutProvider);
      if (!mounted || current == null || current.currentItem == null) return;
      if ('${current.exerciseIndex}/${current.setNumber}/${item.exerciseId}' != key) return;
      _countWithCamera(current);
    });
  }

  void _openSwapSheet(WorkoutSessionState s, WorkoutPlanItem item) {
    showSwapExerciseSheet(
      context: context,
      sessionId: s.session.id,
      item: item,
      currentItems: s.items,
      isExtra: s.isExtra,
      onSwap: (newItem, alt) {
        ref.read(activeWorkoutProvider.notifier).swapCurrentExercise(newItem);
        _lastAnnouncedExerciseIndex = null;
        _announceSetStart(newItem, s);
      },
    );
  }

  void _announceSetStart(WorkoutPlanItem item, WorkoutSessionState s) {
    final coach = ref.read(voiceCoachProvider);
    if (_lastAnnouncedExerciseIndex != s.exerciseIndex) {
      _lastAnnouncedExerciseIndex = s.exerciseIndex;
      coach.speakLine(
        VoiceLineKey.exerciseNext,
        params: {'exercise': item.nameVi},
      );
      final slug = item.exercise?.slug ?? item.exerciseId;
      coach.speakStartTip(slug);
    }
    // Tự mở camera: màn camera tự đếm lùi và đọc "bắt đầu", không đọc hai lần
    if (_autoCameraFor(item)) return;
    coach.speakLine(
      VoiceLineKey.startCountdown,
      params: {'n': '3'},
      interrupt: true,
    );
    _countdownTimer?.cancel();
    _countdownTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) coach.speakLine(VoiceLineKey.go, interrupt: true);
    });
  }


  void _syncInputs(WorkoutSessionState s) {
    final item = s.currentItem;
    if (item == null) return;
    final key = '${s.exerciseIndex}/${s.setNumber}/${item.exerciseId}';
    if (key == _inputKey) return;
    _inputKey = key;
    // Hiệp sau giữ số lần người dùng vừa chọn cho cùng bài (giống mức tạ)
    _reps = s.lastRepsFor(item.exerciseId) ?? item.reps ?? 10;
    _weight = s.lastWeightFor(item.exerciseId) ?? 0;
    _durationSec = 0;
    _spokenDurationSeconds.clear();
    _stopTimer();
  }


  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _timerRunning = false;
  }

  void _toggleTimer() {
    if (_timerRunning) {
      setState(_stopTimer);
      return;
    }
    setState(() => _timerRunning = true);
    final s = ref.read(activeWorkoutProvider);
    final targetSec = s?.currentItem?.durationSec ?? 30;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      // Backend nhận durationSec tối đa 7200 (WorkoutRequest.SetLog).
      if (_durationSec >= _maxDurationSec) {
        setState(_stopTimer);
      } else {
        setState(() => _durationSec++);
        final remaining = targetSec - _durationSec;
        final coach = ref.read(voiceCoachProvider);
        if ((remaining == 30 || remaining == 20 || remaining == 10) &&
            !_spokenDurationSeconds.contains(remaining)) {
          _spokenDurationSeconds.add(remaining);
          coach.speakLine(
            VoiceLineKey.holdRemaining,
            params: {'sec': '$remaining'},
            interrupt: true,
          );
        } else if (remaining <= 5 &&
            remaining >= 1 &&
            !_spokenDurationSeconds.contains(remaining)) {
          _spokenDurationSeconds.add(remaining);
          coach.speakLine(
            VoiceLineKey.holdLast,
            params: {'sec': '$remaining'},
            interrupt: true,
          );
        }
      }
    });
  }

  void _onIncrementReps(WorkoutPlanItem item) {
    if (_reps >= 1000) return;
    final nextReps = _reps + 1;
    setState(() => _reps = nextReps);

    final coach = ref.read(voiceCoachProvider);
    final target = item.reps;
    final countEvery = coach.countEveryForStyle();

    if (target != null && target - nextReps == 3) {
      coach.speakLine(
        VoiceLineKey.almostDone,
        params: {'left': '3'},
        interrupt: true,
      );
    } else if (target != null && nextReps >= target) {
      coach.speakLine(VoiceLineKey.lastRep, interrupt: true);
    } else if (nextReps % countEvery == 0) {
      coach.speakLine(
        VoiceLineKey.rep,
        params: {'n': '$nextReps'},
        interrupt: true,
      );
    }
  }

  void _startRest(int seconds) {
    _restTimer?.cancel();
    if (seconds <= 0) return;
    setState(() => _restRemaining = seconds);
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = (_restRemaining ?? 0) - 1;
      if (left == 10) {
        ref.read(voiceCoachProvider).speakLine(
          VoiceLineKey.restEnding,
          params: {'sec': '10'},
          interrupt: true,
        );
      }
      if (left <= 0) {
        _endRest();
      } else {
        setState(() => _restRemaining = left);
      }
    });
  }

  void _endRest() {
    _restTimer?.cancel();
    _restTimer = null;
    setState(() => _restRemaining = null);
    final s = ref.read(activeWorkoutProvider);
    final item = s?.currentItem;
    if (s != null && item != null) {
      _announceSetStart(item, s);
    }
  }

  void _afterLog(int rest) {
    final s = ref.read(activeWorkoutProvider);
    if (s == null) return;
    if (s.allExercisesDone) {
      _goFinish();
    } else {
      _startRest(rest);
    }
  }

  void _logManual(WorkoutPlanItem item) {
    final duration = item.tracking == TrackingMode.duration;
    _stopTimer();
    final s = ref.read(activeWorkoutProvider);
    final rest = ref
        .read(activeWorkoutProvider.notifier)
        .logSet(
          SetLog(
            exerciseId: item.exerciseId,
            setIndex: 1,
            reps: duration ? null : _reps,
            weightKg: item.tracking == TrackingMode.repsWeight ? _weight : null,
            durationSec: duration ? _durationSec : null,
            repSource: RepSource.manual,
          ),
        );

    final coach = ref.read(voiceCoachProvider);
    if (s != null) {
      coach.speakLine(
        VoiceLineKey.setDone,
        params: {'set': '${s.setNumber}', 'sets': '${item.sets}'},
        interrupt: true,
      );
      if (rest > 0 && !s.allExercisesDone) {
        coach.speakLine(VoiceLineKey.restStart, params: {'sec': '$rest'});
      }
    }

    _afterLog(rest);
  }

  Future<void> _countWithCamera(WorkoutSessionState s) async {
    final item = s.currentItem!;
    final outcome = await context.push<CameraSetOutcome>(
      '/workout/camera',
      extra: CameraSetArgs(
        item: item,
        setNumber: s.setNumber,
        initialWeightKg: _weight,
        targetReps: _reps,
      ),
    );
    if (!mounted || outcome == null || outcome.set == null) return;
    final rest = ref.read(activeWorkoutProvider.notifier).logSet(outcome.set!);
    _afterLog(rest);
  }

  void _skipExercise() {
    ref.read(activeWorkoutProvider.notifier).skipExercise();
    final s = ref.read(activeWorkoutProvider);
    if (s != null && s.allExercisesDone) _goFinish();
  }

  void _goFinish() {
    final s = ref.read(activeWorkoutProvider);
    if (s == null) return;
    if (s.sets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn chưa tập hiệp nào nên buổi này chưa được lưu.'),
        ),
      );
      ref.read(activeWorkoutProvider.notifier).discard();
      context.go('/home');
      return;
    }
    ref.read(activeWorkoutProvider.notifier).finish();
    context.pushReplacement('/workout/finish');
  }

  Future<void> _confirmExit() async {
    final s = ref.read(activeWorkoutProvider);
    final hasSets = s != null && s.sets.isNotEmpty;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Dừng buổi tập?'),
        content: Text(
          hasSets
              ? 'Bạn có thể kết thúc sớm và lưu các hiệp đã tập.'
              : 'Bạn chưa tập hiệp nào, buổi này sẽ không được lưu.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Bỏ buổi'),
          ),
          if (hasSets)
            TextButton(
              onPressed: () => Navigator.pop(context, 'finish'),
              child: const Text('Kết thúc và lưu'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('Tập tiếp'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'finish') {
      _goFinish();
    } else if (choice == 'discard') {
      ref.read(activeWorkoutProvider.notifier).discard();
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(activeWorkoutProvider);
    if (s == null) {
      return Scaffold(
        body: GradientBackground(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: PrimaryButton(
                label: 'Về trang chủ',
                onPressed: () => context.go('/home'),
              ),
            ),
          ),
        ),
      );
    }
    final item = s.currentItem;
    if (item != null) {
      _syncInputs(s);
      _maybeAutoCamera(s, item);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: item == null
                ? const Center(child: CircularProgressIndicator())
                : _restRemaining != null
                ? _RestView(
                    seconds: _restRemaining!,
                    next: item,
                    setNumber: s.setNumber,
                    onAdd: () =>
                        setState(() => _restRemaining = _restRemaining! + 15),
                    onSkip: _endRest,
                  )
                : _buildExercise(s, item),
          ),
        ),
      ),
    );
  }

  Widget _buildExercise(WorkoutSessionState s, WorkoutPlanItem item) {
    final exercise = item.exercise;
    final factory = ref.watch(repSessionFactoryProvider);
    final canCamera = factory.supports(exercise?.camera);
    final total = s.items.length;
    final progress = (s.exerciseIndex + (s.setNumber - 1) / item.sets) / total;
    final cues = exercise?.cues ?? const <String>[];
    final target = item.tracking == TrackingMode.duration
        ? 'Mục tiêu ${item.durationSec ?? 30} giây'
        : 'Mục tiêu ${item.reps ?? 10} lần';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              WorkoutHeader(
                title: 'LevelUp',
                stepLabel: '${s.exerciseIndex + 1}/$total',
                progress: progress,
                trailing: const VoiceMuteButton(),
                onClose: _confirmExit,
              ),
              const SizedBox(height: 18),
              Row(

                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      item.nameVi,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (s.setsDoneFor(item.exerciseId) == 0) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      key: const ValueKey('swap-exercise-active-btn'),
                      onPressed: () => _openSwapSheet(s, item),
                      icon: const Icon(
                        Icons.swap_horiz_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      label: const Text(
                        'Đổi bài này',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 4),
              Text(
                'Hiệp ${s.setNumber}/${item.sets} · $target',
                key: const ValueKey('workout-set-meta'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              _GuideCard(
                item: item,
                instructions: exercise?.instructions,
                hasVideo: exercise?.videoUrl != null,
              ),
              const SizedBox(height: 14),
              if (item.tracking == TrackingMode.duration)
                _DurationInput(
                  seconds: _durationSec,
                  targetSec: item.durationSec ?? 30,
                  running: _timerRunning,
                  onToggle: _toggleTimer,
                  onAdjust: (delta) => setState(() {
                    _durationSec = (_durationSec + delta).clamp(
                      0,
                      _maxDurationSec,
                    );
                  }),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        label: '$_reps lần',
                        child: CounterCard(
                          label: 'Số lần',
                          value: '$_reps',
                          valueKey: const ValueKey('manual-reps'),
                          onDecrement: _reps > 0
                              ? () => setState(() => _reps--)
                              : null,
                          onIncrement: _reps < 1000
                              ? () => _onIncrementReps(item)
                              : null,
                        ),
                      ),
                    ),
                    if (item.tracking == TrackingMode.repsWeight) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: CounterCard(
                          label: 'Tạ (kg)',
                          value: _formatKg(_weight),
                          valueKey: const ValueKey('manual-weight'),
                          onDecrement: _weight > 0
                              ? () => setState(
                                  () => _weight = (_weight - 1).clamp(0, 500),
                                )
                              : null,
                          onIncrement: () => setState(
                            () => _weight = (_weight + 1).clamp(0, 500),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              if (cues.isNotEmpty) ...[
                const SizedBox(height: 14),
                TipBox(
                  icon: Icons.tips_and_updates_outlined,
                  child: Text(cues.join('\n')),
                ),
              ],
              if (item.restSec > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Nghỉ ${item.restSec} giây sau hiệp này',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: canCamera
              ? Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Đếm tay: xong hiệp',
                        height: 52,
                        onPressed:
                            item.tracking == TrackingMode.duration &&
                                _durationSec == 0
                            ? null
                            : () => _logManual(item),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Đếm bằng camera',
                        icon: const Icon(
                          Icons.videocam_rounded,
                          color: AppColors.surface,
                          size: 20,
                        ),
                        onPressed: () => _countWithCamera(s),
                      ),
                    ),
                  ],
                )
              : PrimaryButton(
                  label: 'Xong hiệp',
                  // Bài theo thời gian: phải bấm giờ hoặc nhập tay trước.
                  onPressed:
                      item.tracking == TrackingMode.duration &&
                          _durationSec == 0
                      ? null
                      : () => _logManual(item),
                ),
        ),
        TextButton(
          onPressed: _skipExercise,
          child: const Text('Bỏ qua bài này'),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

String _formatKg(double kg) =>
    kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toStringAsFixed(1);

class _GuideCard extends StatefulWidget {
  const _GuideCard({
    required this.item,
    required this.instructions,
    required this.hasVideo,
  });

  final WorkoutPlanItem item;
  final String? instructions;
  final bool hasVideo;

  @override
  State<_GuideCard> createState() => _GuideCardState();
}

class _GuideCardState extends State<_GuideCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.instructions;
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ExerciseImage(
                  slug: widget.item.exercise?.slug ?? widget.item.exerciseId,
                  thumbnailUrl: widget.item.exercise?.thumbnailUrl,
                  height: 160,
                  width: double.infinity,
                ),
                if (widget.hasVideo)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          if (text != null && text.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              text,
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textPrimary,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Thu gọn' : 'Xem cách tập'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bài tính theo thời gian: đồng hồ bấm giờ + chỉnh tay ±5 giây.
/// Bài có camera (plank, wall sit) còn có nút "Đếm bằng camera" đo thời gian giữ.
class _DurationInput extends StatelessWidget {
  const _DurationInput({
    required this.seconds,
    required this.targetSec,
    required this.running,
    required this.onToggle,
    required this.onAdjust,
  });

  final int seconds;
  final int targetSec;
  final bool running;
  final VoidCallback onToggle;
  final ValueChanged<int> onAdjust;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: [
          const Text(
            'Thời gian giữ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatClock(seconds),
            key: const ValueKey('duration-clock'),
            style: const TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            'Mục tiêu ${formatClock(targetSec)}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          WorkoutProgressBar(
            progress: targetSec == 0 ? 0 : seconds / targetSec,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: seconds >= 5 ? () => onAdjust(-5) : null,
                child: const Text('−5s'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: onToggle,
                icon: Icon(
                  running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(running ? 'Tạm dừng' : 'Bấm giờ'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => onAdjust(5),
                child: const Text('+5s'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RestView extends StatelessWidget {
  const _RestView({
    required this.seconds,
    required this.next,
    required this.setNumber,
    required this.onAdd,
    required this.onSkip,
  });

  final int seconds;
  final WorkoutPlanItem next;
  final int setNumber;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Text(
            'Nghỉ ngơi giữa hiệp',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Hít thở đều và uống nước',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Text(
            formatClock(seconds),
            key: const ValueKey('rest-clock'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ExerciseImage(
                    slug: next.exercise?.slug ?? next.exerciseId,
                    thumbnailUrl: next.exercise?.thumbnailUrl,
                    width: 44,
                    height: 44,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tiếp theo: ${next.nameVi}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hiệp $setNumber/${next.sets}',
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
          const Spacer(),
          SecondaryButton(label: 'Thêm 15 giây', onPressed: onAdd),
          const SizedBox(height: 12),
          PrimaryButton(label: 'Bỏ qua nghỉ', onPressed: onSkip),
        ],
      ),
    );
  }
}
