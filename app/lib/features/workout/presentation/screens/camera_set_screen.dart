import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/gradient_background.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../data/camera/camera_permission.dart';
import '../../data/camera/rep_counting_session.dart';
import '../../domain/models/exercise_response.dart';
import '../../domain/models/workout_models.dart';
import '../../domain/models/workout_session_state.dart';
import '../../../../core/voice/voice_models.dart';
import '../../../../core/voice/voice_provider.dart';
import '../controllers/workout_controller.dart';
import '../widgets/workout_widgets.dart';

class CameraSetArgs {
  final WorkoutPlanItem item;
  final int setNumber;
  final double initialWeightKg;

  /// Số lần mục tiêu người dùng đang chọn ở màn Đang tập (null = theo kế hoạch).
  final int? targetReps;

  const CameraSetArgs({
    required this.item,
    required this.setNumber,
    this.initialWeightKg = 0,
    this.targetReps,
  });
}

/// Kết quả trả về màn Đang tập. [set] null nghĩa là người dùng chọn đếm tay.
class CameraSetOutcome {
  final SetLog? set;
  const CameraSetOutcome(this.set);
}

enum _Stage { setup, counting, confirm }

/// Một hiệp đếm bằng camera (F2b): Đặt camera → Đang đếm → Xác nhận.
/// Khung hình chỉ xử lý trên điện thoại, không lưu và không gửi đi.
class CameraSetScreen extends ConsumerStatefulWidget {
  const CameraSetScreen({super.key, required this.args});

  final CameraSetArgs args;

  @override
  ConsumerState<CameraSetScreen> createState() => _CameraSetScreenState();
}

class _CameraSetScreenState extends ConsumerState<CameraSetScreen> {
  _Stage _stage = _Stage.setup;
  // Đang kiểm tra "Không hỏi lại hôm nay" → chưa vẽ màn Đặt camera để khỏi nháy
  bool _checkingSkip = true;

  @override
  void initState() {
    super.initState();
    unawaited(_maybeSkipSetup());
  }

  /// Đã chọn bỏ qua hôm nay và quyền camera vẫn còn → vào đếm luôn.
  Future<void> _maybeSkipSetup() async {
    var skip = false;
    try {
      final today = localDateString(DateTime.now());
      if (await ref.read(cameraSetupSkipProvider).skippedDate() == today) {
        skip =
            await ref.read(cameraPermissionProvider).request() ==
            CameraPermissionResult.granted;
      }
    } catch (_) {
      skip = false;
    }
    if (!mounted) return;
    setState(() {
      _checkingSkip = false;
      if (skip) _stage = _Stage.counting;
    });
  }

  RepSnapshot? _snapshot;
  // Đổi key để tạo phiên đếm mới khi "Đếm lại".
  int _attempt = 0;

  WorkoutPlanItem get item => widget.args.item;
  ExerciseCamera get camera => item.exercise!.camera!;

  void _manual() => context.pop(const CameraSetOutcome(null));

  @override
  Widget build(BuildContext context) {
    final subtitle = 'Hiệp ${widget.args.setNumber}/${item.sets}';
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: _checkingSkip
              ? const Center(child: CircularProgressIndicator())
              : switch (_stage) {
                  _Stage.setup => _SetupView(
                    item: item,
                    name: item.nameVi,
                    subtitle: subtitle,
                    camera: camera,
                    onReady: () => setState(() => _stage = _Stage.counting),
                    onManual: _manual,
                  ),
                  _Stage.counting => _CountingView(
                    key: ValueKey('counting-$_attempt'),
                    name: item.nameVi,
                    subtitle: subtitle,
                    camera: camera,
                    slug: item.exercise?.slug ?? item.exerciseId,
                    targetReps: widget.args.targetReps ?? item.reps,
                    targetSec: item.durationSec,
                    onManual: _manual,
                    onDone: (snapshot) => setState(() {
                      _snapshot = snapshot;
                      _stage = _Stage.confirm;
                    }),
                  ),
                  _Stage.confirm => _ConfirmView(
                    args: widget.args,
                    camera: camera,
                    snapshot: _snapshot ?? const RepSnapshot(),
                    onRecount: () => setState(() {
                      _attempt++;
                      _stage = _Stage.counting;
                    }),
                    onSave: (set) => context.pop(CameraSetOutcome(set)),
                  ),
                },
        ),
      ),
    );
  }
}

/// Mẹo đặt máy theo cameraPosition của bài.
List<String> cameraTipsVi(ExerciseCamera camera) {
  final position = switch (camera.cameraPosition) {
    'side' =>
      'Đứng nghiêng người về phía camera để máy thấy rõ hông, gối và cổ chân.',
    'front' => 'Đứng đối diện camera, hai vai ngang nhau.',
    'back' => 'Quay lưng về phía camera.',
    _ => 'Đứng sao cho camera thấy rõ các khớp đang chuyển động.',
  };
  final custom = camera.config?['setupTipVi'];
  return [
    'Dựng máy ngang tầm hông, cách bạn khoảng 2 m.',
    position,
    'Đứng lọt cả người, từ đầu tới chân, trong khung hình.',
    if (custom is String && custom.trim().isNotEmpty) custom.trim(),
  ];
}

class _SetupView extends ConsumerStatefulWidget {
  const _SetupView({
    required this.item,
    required this.name,
    required this.subtitle,
    required this.camera,
    required this.onReady,
    required this.onManual,
  });

  final WorkoutPlanItem item;
  final String name;
  final String subtitle;
  final ExerciseCamera camera;
  final VoidCallback onReady;
  final VoidCallback onManual;

  @override
  ConsumerState<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends ConsumerState<_SetupView> {
  CameraPermissionResult? _denied;
  bool _busy = false;
  bool _dontAskToday = false;

  Future<void> _ready() async {
    setState(() => _busy = true);
    final result = await ref.read(cameraPermissionProvider).request();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == CameraPermissionResult.granted) {
      _denied = null;
      if (_dontAskToday) {
        await ref
            .read(cameraSetupSkipProvider)
            .skipFor(localDateString(DateTime.now()));
        if (!mounted) return;
      }
      widget.onReady();
    } else {
      setState(() => _denied = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tips = cameraTipsVi(widget.camera);
    final slug = widget.item.exercise?.slug ?? widget.item.exerciseId;
    final coach = ref.watch(voiceCoachProvider);
    final startTips = coach.getStartTips(slug).isNotEmpty
        ? coach.getStartTips(slug)
        : (widget.item.exercise?.cues ?? const <String>[]);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              WorkoutHeader(
                title: widget.name,
                subtitle: widget.subtitle,
                closeIcon: Icons.chevron_left_rounded,
                trailing: const VoiceMuteButton(),
                onClose: widget.onManual,
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ExerciseImage(
                  slug: widget.item.exercise?.slug ?? widget.item.exerciseId,
                  thumbnailUrl: widget.item.exercise?.thumbnailUrl,
                  height: 160,
                  width: double.infinity,
                ),
              ),
              if (startTips.isNotEmpty) ...[
                const SizedBox(height: 14),
                TipBox(
                  key: const ValueKey('camera-setup-start-tip'),
                  icon: Icons.lightbulb_outline_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mẹo kỹ thuật',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final tip in startTips)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(tip),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                'Đặt điện thoại để camera đếm giúp bạn',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: SizedBox(
                  height: 120,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: const [
                      Icon(
                        Icons.smartphone_rounded,
                        size: 40,
                        color: AppColors.textPrimary,
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          '← khoảng 2 m →',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.accessibility_new_rounded,
                        size: 96,
                        color: AppColors.textPrimary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final tip in tips)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6, right: 10),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                tip,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.4,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const TipBox(
                      icon: Icons.lock_outline_rounded,
                      child: Text(
                        'Hình ảnh chỉ được xử lý ngay trên điện thoại. '
                        'App không gửi lên server và không lưu video.',
                      ),
                    ),
                  ],
                ),
              ),
              if (_denied != null) ...[
                const SizedBox(height: 14),
                ErrorBanner(
                  message:
                      'LevelUp cần quyền camera để đếm số lần. '
                      'Bạn có thể cấp quyền hoặc tự đếm tay.',
                  retryLabel:
                      _denied == CameraPermissionResult.permanentlyDenied
                      ? 'Mở cài đặt'
                      : 'Thử lại',
                  onRetry: _denied == CameraPermissionResult.permanentlyDenied
                      ? () => ref.read(cameraPermissionProvider).openSettings()
                      : _ready,
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              CheckboxListTile(
                key: const ValueKey('camera-skip-today'),
                value: _dontAskToday,
                onChanged: (v) => setState(() => _dontAskToday = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                title: const Text(
                  'Không hỏi lại hôm nay, lần sau vào đếm luôn',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
              ),
              PrimaryButton(
                label: 'Tôi đã sẵn sàng',
                isLoading: _busy,
                onPressed: _ready,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SecondaryButton(
                  label: 'Tự đếm tay',
                  onPressed: widget.onManual,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CountingView extends ConsumerStatefulWidget {
  const _CountingView({
    super.key,
    required this.name,
    required this.subtitle,
    required this.camera,
    this.slug = '',
    required this.targetReps,
    this.targetSec,
    required this.onManual,
    required this.onDone,
  });

  final String name;
  final String subtitle;
  final ExerciseCamera camera;
  final String slug;
  final int? targetReps;
  final int? targetSec;
  final VoidCallback onManual;
  final ValueChanged<RepSnapshot> onDone;

  @override
  ConsumerState<_CountingView> createState() => _CountingViewState();
}

class _CountingViewState extends ConsumerState<_CountingView>
    with WidgetsBindingObserver {
  RepCountingSession? _session;
  StreamSubscription<RepSnapshot>? _sub;
  RepSnapshot _latest = const RepSnapshot();
  String? _error;
  bool _busy = false;
  bool _foreground = true;
  bool _autoFinishing = false;

  // Countdown trước khi đếm: 3.. 2.. 1.. go
  int _countdownSec = 3;
  bool _countingDown = true;
  Timer? _countdownTimer;

  int _lastRep = 0;
  final Set<int> _spokenHoldSeconds = {};
  DateTime _lastFormIssueTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastLostPersonTime = DateTime.fromMillisecondsSinceEpoch(0);

  /// Thời gian chờ sau khi đạt mục tiêu, để người tập thấy con số cuối rồi mới chuyển màn.
  static const autoFinishDelay = Duration(milliseconds: 900);

  /// Đạt mục tiêu của hiệp: đủ số lần (bài đếm lần) hoặc đủ thời gian giữ (plank, wall sit).
  bool _targetReached(RepSnapshot r) {
    if (r.isHold) {
      final target = widget.targetSec;
      return target != null && target > 0 && r.holdDuration.inSeconds >= target;
    }
    final target = widget.targetReps;
    return target != null && target > 0 && r.repCount >= target;
  }

  void _maybeAutoFinish(RepSnapshot r) {
    if (_autoFinishing || _busy || !_targetReached(r)) return;
    _autoFinishing = true;
    Future.delayed(autoFinishDelay, () {
      if (mounted) unawaited(_finish());
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      final session = ref.read(repSessionFactoryProvider).create(widget.camera);
      _session = session;
      _latest = session.latest;
      // Đăng ký trước khi start (README camera_counter).
      _sub = session.results.listen((r) {
        if (!mounted) return;
        setState(() => _latest = r);
        _handleVoiceFeedback(r);
        // Đủ mục tiêu thì tự kết thúc hiệp → màn xác nhận → nghỉ
        _maybeAutoFinish(r);
      });
      _start();
      _startCountdown();
    } catch (e) {
      _error = 'Bài này chưa đếm được bằng camera trên máy bạn.';
    }
  }

  void _startCountdown() {
    final coach = ref.read(voiceCoachProvider);
    _countdownSec = 3;
    _countingDown = true;
    coach.speakLine(
      VoiceLineKey.startCountdown,
      params: {'n': '$_countdownSec'},
      interrupt: true,
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdownSec--;
      });
      if (_countdownSec > 0) {
        coach.speakLine(
          VoiceLineKey.startCountdown,
          params: {'n': '$_countdownSec'},
          interrupt: true,
        );
      } else {
        timer.cancel();
        setState(() {
          _countingDown = false;
        });
        coach.speakLine(VoiceLineKey.go, interrupt: true);
      }
    });
  }

  void _handleVoiceFeedback(RepSnapshot r) {
    if (_countingDown || _autoFinishing || !_foreground) return;
    final coach = ref.read(voiceCoachProvider);

    // 1. Phản hồi số lần (Rep)
    if (!r.isHold) {
      if (r.repCount > _lastRep) {
        final currentRep = r.repCount;
        _lastRep = currentRep;
        final target = widget.targetReps;
        final countEvery = coach.countEveryForStyle();

        if (target != null && target - currentRep == 3) {
          coach.speakLine(
            VoiceLineKey.almostDone,
            params: {'left': '3'},
            interrupt: true,
          );
        } else if (target != null && currentRep >= target) {
          coach.speakLine(VoiceLineKey.lastRep, interrupt: true);
        } else if (currentRep % countEvery == 0) {
          coach.speakLine(
            VoiceLineKey.rep,
            params: {'n': '$currentRep'},
            interrupt: true,
          );
        }
      }
    } else if (r.holding) {
      // 2. Bài giữ (Hold/Duration)
      final target = widget.targetSec;
      if (target != null && target > 0) {
        final remaining = target - r.holdDuration.inSeconds;
        if ((remaining == 30 || remaining == 20 || remaining == 10) &&
            !_spokenHoldSeconds.contains(remaining)) {
          _spokenHoldSeconds.add(remaining);
          coach.speakLine(
            VoiceLineKey.holdRemaining,
            params: {'sec': '$remaining'},
            interrupt: true,
          );
        } else if (remaining <= 5 &&
            remaining >= 1 &&
            !_spokenHoldSeconds.contains(remaining)) {
          _spokenHoldSeconds.add(remaining);
          coach.speakLine(
            VoiceLineKey.holdLast,
            params: {'sec': '$remaining'},
            interrupt: true,
          );
        }
      }
    }

    // 3. Tư thế sai (Tối đa 1 lần / 8 giây)
    final now = DateTime.now();
    if (r.issues.isNotEmpty &&
        now.difference(_lastFormIssueTime).inSeconds >= 8) {
      _lastFormIssueTime = now;
      final issueCode = r.issues.last.code;
      coach.speakFormCue(widget.slug, issueCode, interrupt: false);
    }

    // 4. Mất người (Tối đa 1 lần / 8 giây)
    if (r.personMissing &&
        now.difference(_lastLostPersonTime).inSeconds >= 8) {
      _lastLostPersonTime = now;
      coach.speakLine(VoiceLineKey.lostPerson, interrupt: false);
    }
  }

  Future<void> _start() async {
    final session = _session;
    if (session == null || _busy || !_foreground) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await session.start();
      if (!_foreground) await session.pause();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pause() async {
    try {
      await _session?.pause();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(voiceCoachProvider).setAppLifecycle(state);
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    // Ra nền thì nhả camera; quay lại người dùng tự bấm "Tiếp tục".
    if (!foreground) unawaited(_pause());
  }

  Future<void> _finish() async {
    final session = _session;
    if (session == null) return;
    setState(() => _busy = true);
    try {
      await session.stop();
    } catch (_) {
      // Vẫn dùng kết quả cuối cùng đã nhận.
    }
    if (!mounted) return;
    final latest = session.latest;
    final better = latest.isHold
        ? latest.holdDuration >= _latest.holdDuration
        : latest.repCount >= _latest.repCount;
    widget.onDone(better ? latest : _latest);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_sub?.cancel());
    final session = _session;
    if (session != null) {
      // Luôn tắt camera khi rời màn, kể cả khi bấm back.
      unawaited(session.stop().then<void>((_) {}, onError: (Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _latest;
    final running = r.status == RepCountingStatus.running;
    final error = _error ?? r.error;
    final controller = _session?.cameraController;
    final lastIssue = r.issues.isNotEmpty ? r.issues.last : null;
    final statusText = _countingDown
        ? 'Sắp bắt đầu ($_countdownSec)'
        : !running
        ? (r.status == RepCountingStatus.paused
              ? 'Đã tạm dừng'
              : 'Đang mở camera…')
        : r.personMissing
        ? 'Không thấy người'
        : 'Đã thấy toàn thân';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkoutHeader(
            title: widget.name,
            subtitle: widget.subtitle,
            stepLabel: statusText,
            trailing: const VoiceMuteButton(),
            onClose: widget.onManual,
          ),
          const SizedBox(height: 14),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: AppColors.textPrimary,
                    child: controller != null && controller.value.isInitialized
                        ? Center(child: CameraPreview(controller))
                        : const Center(
                            child: Icon(
                              Icons.videocam_outlined,
                              size: 48,
                              color: AppColors.surface,
                            ),
                          ),
                  ),
                  if (_countingDown)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.6),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_countdownSec',
                              key: const ValueKey('camera-countdown-number'),
                              style: const TextStyle(
                                fontSize: 96,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Chuẩn bị...',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (running && r.personMissing)
                    const Positioned(
                      left: 12,
                      right: 12,
                      top: 12,
                      child: _OverlayBanner(
                        icon: Icons.person_off_outlined,
                        text:
                            'Không thấy người. Lùi xa để camera thấy vai, '
                            'hông, gối và cổ chân.',
                      ),
                    ),
                  if (lastIssue != null)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: _OverlayBanner(
                        key: const ValueKey('form-warning'),
                        icon: Icons.south_rounded,
                        text:
                            'Lần ${lastIssue.repIndex}: '
                            '${formIssueLabelVi(lastIssue.code)}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Semantics(
                liveRegion: true,
                label: r.isHold
                    ? '${r.holdDuration.inSeconds} giây'
                    : '${r.repCount} lần',
                child: Text(
                  r.isHold
                      ? formatClock(r.holdDuration.inSeconds)
                      : '${r.repCount}',
                  key: const ValueKey('camera-rep-count'),
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                r.isHold
                    ? (r.holding
                          ? 'đang giữ đúng tư thế'
                          : (widget.targetSec != null
                                ? '/ ${formatClock(widget.targetSec!)}'
                                : 'giữ tư thế'))
                    : widget.targetReps != null
                    ? '/ ${widget.targetReps} lần'
                    : 'lần',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (error != null) ...[
            ErrorBanner(
              message: r.permissionDenied
                  ? 'Chưa có quyền camera. Cho phép LevelUp dùng camera trong Cài đặt.'
                  : cameraErrorMessage(error),
              retryLabel: r.permissionDenied ? 'Mở cài đặt' : 'Thử lại',
              onRetry: _session == null
                  ? null
                  : r.permissionDenied
                  ? () => ref.read(cameraPermissionProvider).openSettings()
                  : _start,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: running ? 'Tạm dừng' : 'Tiếp tục',
                  height: 52,
                  onPressed: _session == null || _busy
                      ? null
                      : running
                      ? _pause
                      : _start,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Xong hiệp',
                  onPressed: _session == null || _busy ? null : _finish,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: widget.onManual,
            child: const Text('Chuyển sang đếm tay'),
          ),
        ],
      ),
    );
  }
}

class _OverlayBanner extends StatelessWidget {
  const _OverlayBanner({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lỗi camera/ML Kit (thường là chuỗi kỹ thuật tiếng Anh) → câu tiếng Việt cho người dùng.
String cameraErrorMessage(String raw) {
  debugPrint('[camera] lỗi: $raw');
  final s = raw.toLowerCase();
  if (s.contains('accessdenied') || s.contains('permission')) {
    return 'Chưa có quyền camera. Cho phép LevelUp dùng camera trong Cài đặt.';
  }
  if (s.contains('no front') ||
      s.contains('front camera') ||
      s.contains('nocamera') ||
      s.contains('no camera')) {
    return 'Không tìm thấy camera trước trên máy này. Bạn đếm tay giúp mình nhé.';
  }
  if (s.contains('in use') ||
      s.contains('max_cameras') ||
      s.contains('disabled')) {
    return 'Camera đang được ứng dụng khác dùng. Đóng ứng dụng đó rồi bấm Thử lại.';
  }
  return 'Camera đang gặp sự cố. Bấm Thử lại hoặc chuyển sang đếm tay.';
}

/// Tạo SetLog từ kết quả camera và số lần người dùng xác nhận.
SetLog buildCameraSetLog({
  required WorkoutPlanItem item,
  required ExerciseCamera camera,
  required RepSnapshot snapshot,
  required int confirmedReps,
  double? weightKg,
  int? confirmedSeconds,
}) {
  final confidence = snapshot.averageConfidence.clamp(0.0, 1.0);
  if (snapshot.isHold) {
    // Giữ tư thế: lưu thời gian (giới hạn backend 7200 giây), không có số lần.
    final measured = snapshot.holdDuration.inSeconds.clamp(0, 7200);
    final seconds = (confirmedSeconds ?? measured).clamp(0, 7200);
    return SetLog(
      exerciseId: item.exerciseId,
      setIndex: 1,
      durationSec: seconds,
      repSource: seconds == measured
          ? RepSource.camera
          : RepSource.cameraCorrected,
      cvVersion: camera.version,
      avgConfidence: double.parse(confidence.toStringAsFixed(3)),
      formScore: measured > 0 ? snapshot.formScore.clamp(0, 100) : null,
      formIssues: snapshot.issues.take(100).toList(),
    );
  }
  final detected = snapshot.repCount;
  return SetLog(
    exerciseId: item.exerciseId,
    setIndex: 1,
    reps: confirmedReps,
    weightKg: item.tracking == TrackingMode.repsWeight ? weightKg : null,
    repSource: confirmedReps == detected
        ? RepSource.camera
        : RepSource.cameraCorrected,
    repsDetected: detected,
    cvVersion: camera.version,
    avgConfidence: double.parse(confidence.toStringAsFixed(3)),
    formScore: detected > 0 ? snapshot.formScore.clamp(0, 100) : null,
    formIssues: snapshot.issues.take(100).toList(),
  );
}

class _ConfirmView extends StatefulWidget {
  const _ConfirmView({
    required this.args,
    required this.camera,
    required this.snapshot,
    required this.onRecount,
    required this.onSave,
  });

  final CameraSetArgs args;
  final ExerciseCamera camera;
  final RepSnapshot snapshot;
  final VoidCallback onRecount;
  final ValueChanged<SetLog> onSave;

  @override
  State<_ConfirmView> createState() => _ConfirmViewState();
}

class _ConfirmViewState extends State<_ConfirmView> {
  late int _reps = widget.snapshot.repCount;
  late final int _measuredSec = widget.snapshot.holdDuration.inSeconds.clamp(
    0,
    7200,
  );
  late int _seconds = _measuredSec;
  late double _weight = widget.args.initialWeightKg;

  @override
  Widget build(BuildContext context) {
    final item = widget.args.item;
    final s = widget.snapshot;
    final withWeight = item.tracking == TrackingMode.repsWeight;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              Text(
                '${item.nameVi} · Xong hiệp ${widget.args.setNumber}/${item.sets}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.isHold
                    ? 'Camera đo được ${formatClock(_measuredSec)} giữ tư thế'
                    : 'Camera đếm được ${s.repCount} lần',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Sai số thì sửa lại cho đúng trước khi lưu.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: s.isHold
                        ? CounterCard(
                            label: 'Thời gian giữ',
                            value: formatClock(_seconds),
                            valueKey: const ValueKey('confirm-seconds'),
                            onDecrement: _seconds > 0
                                ? () => setState(
                                    () => _seconds = (_seconds - 5).clamp(
                                      0,
                                      7200,
                                    ),
                                  )
                                : null,
                            onIncrement: _seconds < 7200
                                ? () => setState(
                                    () => _seconds = (_seconds + 5).clamp(
                                      0,
                                      7200,
                                    ),
                                  )
                                : null,
                          )
                        : CounterCard(
                            label: 'Số lần',
                            value: '$_reps',
                            valueKey: const ValueKey('confirm-reps'),
                            onDecrement: _reps > 0
                                ? () => setState(() => _reps--)
                                : null,
                            onIncrement: _reps < 1000
                                ? () => setState(() => _reps++)
                                : null,
                          ),
                  ),
                  if (withWeight) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: CounterCard(
                        label: 'Tạ (kg)',
                        value: _weight == _weight.roundToDouble()
                            ? _weight.toInt().toString()
                            : _weight.toStringAsFixed(1),
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
              if (s.isHold
                  ? _seconds != _measuredSec
                  : _reps != s.repCount) ...[
                const SizedBox(height: 8),
                const Text(
                  'Đã sửa kết quả, coach sẽ ghi là bạn chỉnh lại.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              if (s.isHold ? _measuredSec > 0 : s.repCount > 0)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Điểm tư thế',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Text(
                            '${s.formScore}/100',
                            key: const ValueKey('form-score'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (s.issues.isEmpty)
                        const Text(
                          'Không thấy lỗi tư thế nào. Giữ vững nhé!',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      for (final issue in s.issues)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: TipBox(
                            child: Text(
                              'Lần ${issue.repIndex}: '
                              '${formIssueLabelVi(issue.code)}'
                              '${issue.severity >= 3 ? ' (rõ)' : ''}',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              PrimaryButton(
                label: 'Lưu hiệp',
                onPressed: () => widget.onSave(
                  buildCameraSetLog(
                    item: item,
                    camera: widget.camera,
                    snapshot: s,
                    confirmedReps: _reps,
                    weightKg: _weight,
                    confirmedSeconds: s.isHold ? _seconds : null,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SecondaryButton(
                  label: 'Đếm lại hiệp này',
                  onPressed: widget.onRecount,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
