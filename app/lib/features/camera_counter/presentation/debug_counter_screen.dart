import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/camera_rep_session.dart';
import '../domain/cv_config.dart';

/// Temporary device-test screen; the production F2b screen can use the session.
class DebugCounterScreen extends StatefulWidget {
  const DebugCounterScreen({super.key, this.config});

  final CvConfig? config;

  @override
  State<DebugCounterScreen> createState() => _DebugCounterScreenState();
}

class _DebugCounterScreenState extends State<DebugCounterScreen>
    with WidgetsBindingObserver {
  CameraRepSession? _session;
  StreamSubscription<CameraRepResult>? _subscription;
  CameraRepResult? _result;
  String? _error;
  bool _busy = false;
  bool _foreground = true;

  late final _config =
      widget.config ??
      CvConfig.fromJson({
        'joints': ['hip', 'knee', 'ankle'],
        'downBelow': 120,
        'upAbove': 160,
        'minConfidence': 0.6,
        'minRepMs': 600,
      });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_start());
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

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final controller = _session?.cameraController;
    final error = _error ?? result?.error;
    final status = result?.status ?? CameraRepSessionStatus.idle;
    return Scaffold(
      appBar: AppBar(title: const Text('Camera squat • Debug')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Text(
                '${result?.repCount ?? 0} lần',
                key: const ValueKey('debug-rep-count'),
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              Text(switch (status) {
                CameraRepSessionStatus.idle => 'Đang chuẩn bị camera',
                CameraRepSessionStatus.running => 'Đang đếm',
                CameraRepSessionStatus.paused => 'Đã tạm dừng • bấm Tiếp tục',
                CameraRepSessionStatus.stopped =>
                  'Đã kết thúc • Bắt đầu tạo hiệp mới',
              }),
              if (result?.personMissing == true &&
                  status == CameraRepSessionStatus.running)
                const Text(
                  'Không thấy người. Đứng xa camera để thấy vai, hông, gối và cổ chân.',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
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
                result?.counter.currentAngle == null
                    ? 'Góc gối: chưa có dữ liệu'
                    : 'Góc gối: ${result!.counter.currentAngle!.toStringAsFixed(1)}°',
              ),
              Text(
                'Tin cậy trung bình: ${((result?.averageConfidence ?? 0) * 100).toStringAsFixed(0)}%',
              ),
              Text(
                (result?.repCount ?? 0) == 0
                    ? 'Điểm tư thế: chưa có lần hoàn tất'
                    : 'Điểm tư thế: ${result!.formScore}/100',
              ),
              for (final issue in result?.issues ?? [])
                Text(
                  'Lần ${issue.repIndex}: squat chưa đủ sâu (mức ${issue.severity})',
                ),
              const SizedBox(height: 12),
              const Text(
                'Đứng nghiêng để camera thấy rõ góc gối; đứng thẳng trước khi bắt đầu. '
                'Khung hình chỉ xử lý trên điện thoại, không lưu hoặc gửi đi.',
              ),
              Text(
                'Ngưỡng demo: xuống <${_config.downBelow}°, lên >${_config.upAbove}°.',
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
