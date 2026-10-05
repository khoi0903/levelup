import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/camera_rep_session.dart';
import '../domain/camera_counter.dart';
import 'debug_exercise_configs.dart';

/// Temporary device-test screen; the production F2b screen can use the session.
///
/// Chọn bài từ cấu hình (bản sao của mongo/cv-configs.json); đổi bài sẽ kết
/// thúc hiệp hiện tại và mở hiệp mới với cấu hình đó. Truyền [config] để thử
/// thêm một cấu hình tuỳ ý (đứng đầu danh sách).
class DebugCounterScreen extends StatefulWidget {
  const DebugCounterScreen({super.key, this.config, this.autoStart = true});

  final CvConfig? config;

  /// Mở camera ngay khi vào màn hình và khi đổi bài (tắt trong widget test).
  final bool autoStart;

  @override
  State<DebugCounterScreen> createState() => _DebugCounterScreenState();
}

class _DebugCounterScreenState extends State<DebugCounterScreen>
    with WidgetsBindingObserver {
  late final List<DebugExerciseConfig> _exercises = [
    if (widget.config != null)
      DebugExerciseConfig(
        slug: 'custom',
        nameVi: 'Cấu hình truyền vào',
        cameraPosition: '-',
        config: widget.config!,
      ),
    ...debugExerciseConfigs(),
  ];
  late DebugExerciseConfig _exercise = _exercises.first;
  CameraRepSession? _session;
  StreamSubscription<CameraRepResult>? _subscription;
  CameraRepResult? _result;
  String? _error;
  bool _busy = false;
  bool _foreground = true;

  CvConfig get _config => _exercise.config;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoStart) unawaited(_start());
  }

  Future<void> _start() async {
    if (_busy || !_foreground) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_session == null ||
          _session!.latestResult.status == CameraRepSessionStatus.stopped) {
        await _subscription?.cancel();
        if (!mounted) return;
        final session = CameraRepSession(config: _config);
        _session = session;
        _result = session.latestResult;
        _subscription = session.results.listen((result) {
          if (!mounted || !identical(_session, session)) return;
          setState(() => _result = result);
        });
      }
      await _session!.start();
      if (!_foreground) await _session!.pause();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kết thúc hiệp hiện tại (nếu có) rồi chuyển sang bài [exercise].
  Future<void> _select(DebugExerciseConfig exercise) async {
    if (_busy || identical(exercise, _exercise)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final old = _session;
    final subscription = _subscription;
    _session = null;
    _subscription = null;
    try {
      await subscription?.cancel();
      await old?.stop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
    if (!mounted) return;
    setState(() {
      _exercise = exercise;
      _result = null;
      _busy = false;
    });
    if (widget.autoStart) await _start();
  }

  Future<void> _control(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await operation();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    _foreground = foreground;
    if (!foreground) unawaited(_pauseInBackground());
    // Explicitly tap Continue after returning to the app.
  }

  Future<void> _pauseInBackground() async {
    try {
      await _session?.pause();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_subscription?.cancel());
    final session = _session;
    if (session != null) {
      // Cleanup still runs after this widget is gone; errors cannot be rendered.
      unawaited(
        session.stop().then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      );
    }
    super.dispose();
  }

  /// `mm:ss.s`, ví dụ `01:05.3`.
  static String formatHold(Duration value) {
    final minutes = value.inMinutes.toString().padLeft(2, '0');
    final seconds = (value.inMilliseconds % 60000 / 1000)
        .toStringAsFixed(1)
        .padLeft(4, '0');
    return '$minutes:$seconds';
  }

  String _side(CameraRepResult? result) {
    if (result == null || result.currentAngle == null) return 'chưa có';
    if (result.averagedSides) return 'trung bình hai bên';
    return switch (result.selectedSide) {
      BodySide.left => 'trái',
      BodySide.right => 'phải',
      null => 'chưa có',
    };
  }

  String _thresholds() {
    final c = _config;
    if (c.mode == CvMode.active) {
      return 'Tính giờ khi có chu kỳ chuyển động trong 2 giây gần nhất.';
    }
    if (c.isHold) return 'Giữ khi góc trong ${c.holdMin}°–${c.holdMax}°.';
    return c.direction == CvDirection.flex
        ? 'Đếm: xuống <${c.downBelow}° rồi lên >${c.upAbove}° '
              '(tối thiểu ${c.minRepMs} ms).'
        : 'Đếm: lên >${c.upAbove}° rồi về <${c.downBelow}° '
              '(tối thiểu ${c.minRepMs} ms).';
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final controller = _session?.cameraController;
    final error = _error ?? result?.error;
    final status = result?.status ?? CameraRepSessionStatus.idle;
    final hold = _config.isHold;
    final jointNames = _config.joints.map((joint) => joint.name).join('–');
    final hasScore = hold
        ? (result?.holdDuration ?? Duration.zero) > Duration.zero
        : (result?.repCount ?? 0) > 0;
    final angle = result?.currentAngle;
    final placement = _config.placement;
    return Scaffold(
      appBar: AppBar(title: const Text('Camera counter • Debug')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButton<DebugExerciseConfig>(
                key: const ValueKey('debug-exercise-picker'),
                isExpanded: true,
                value: _exercise,
                onChanged: _busy
                    ? null
                    : (exercise) {
                        if (exercise != null) unawaited(_select(exercise));
                      },
                items: [
                  for (final exercise in _exercises)
                    DropdownMenuItem(
                      value: exercise,
                      child: Text(
                        '${exercise.nameVi} • '
                        '${exercise.config.isHold ? 'giữ' : 'đếm'} • '
                        '${exercise.cameraPosition}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 320,
                child: ColoredBox(
                  color: Colors.black,
                  child: controller != null && controller.value.isInitialized
                      ? Center(child: CameraPreview(controller))
                      : const Center(
                          child: Text(
                            'Camera chưa mở',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (hold)
                Text(
                  formatHold(result?.holdDuration ?? Duration.zero),
                  key: const ValueKey('debug-hold-duration'),
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: result?.holding == true ? Colors.green : null,
                  ),
                  textAlign: TextAlign.center,
                )
              else
                Text(
                  '${result?.repCount ?? 0} lần',
                  key: const ValueKey('debug-rep-count'),
                  style: Theme.of(context).textTheme.headlineLarge,
                  textAlign: TextAlign.center,
                ),
              Text(switch (status) {
                CameraRepSessionStatus.idle => 'Đang chuẩn bị camera',
                CameraRepSessionStatus.running when hold =>
                  result?.holding == true
                      ? 'Đang giữ đúng tư thế'
                      : 'Chưa vào tư thế',
                CameraRepSessionStatus.running => 'Đang đếm',
                CameraRepSessionStatus.paused => 'Đã tạm dừng • bấm Tiếp tục',
                CameraRepSessionStatus.stopped =>
                  'Đã kết thúc • Bắt đầu tạo hiệp mới',
              }),
              if (result?.personMissing == true &&
                  status == CameraRepSessionStatus.running)
                Text(
                  'Không thấy người. Lùi xa để camera thấy đủ $jointNames.',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (result?.orientationOk == false)
                const Text(
                  'Sai hướng thân (ví dụ đang đứng thay vì nằm), chưa tính.',
                  style: TextStyle(color: Colors.orange),
                ),
              if (error != null)
                Text(error, style: const TextStyle(color: Colors.red)),
              if (error?.contains('CameraAccessDenied') == true)
                TextButton(
                  onPressed: () async {
                    await openAppSettings();
                  },
                  child: const Text('Mở cài đặt quyền camera'),
                ),
              Text(
                angle == null
                    ? 'Góc $jointNames: chưa có dữ liệu'
                    : 'Góc $jointNames: ${angle.toStringAsFixed(1)}°',
                key: const ValueKey('debug-angle'),
              ),
              Text('Bên: ${_side(result)}'),
              Text(
                'Tin cậy trung bình: '
                '${((result?.averageConfidence ?? 0) * 100).toStringAsFixed(0)}%',
              ),
              Text(
                hasScore
                    ? 'Điểm tư thế: ${result!.formScore}/100'
                    : 'Điểm tư thế: chưa có dữ liệu',
              ),
              for (final issue in result?.issues ?? const <FormIssue>[])
                Text(
                  hold
                      ? 'Lỗi ${issue.code} (mức ${issue.severity})'
                      : 'Lần ${issue.repIndex}: ${issue.code} '
                            '(mức ${issue.severity})',
                ),
              const SizedBox(height: 12),
              Text(
                _config.setupTipVi ??
                    'Đứng nghiêng để camera thấy rõ $jointNames; '
                        'về tư thế nghỉ trước khi bắt đầu.',
                key: const ValueKey('debug-setup-tip'),
              ),
              Text(
                'Máy: ${_exercise.cameraPosition}'
                '${placement == null ? '' : ' ($placement)'}. '
                '${_thresholds()}',
              ),
              const Text(
                'Khung hình chỉ xử lý trên điện thoại, không lưu hoặc gửi đi.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy || status == CameraRepSessionStatus.running
                        ? null
                        : _start,
                    child: Text(
                      status == CameraRepSessionStatus.paused
                          ? 'Tiếp tục'
                          : 'Bắt đầu',
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _busy || status != CameraRepSessionStatus.running
                        ? null
                        : () => _control(_session!.pause),
                    child: const Text('Tạm dừng'),
                  ),
                  OutlinedButton(
                    onPressed:
                        _busy ||
                            _session == null ||
                            status == CameraRepSessionStatus.stopped
                        ? null
                        : () => _control(_session!.stop),
                    child: const Text('Kết thúc'),
                  ),
                ],
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
