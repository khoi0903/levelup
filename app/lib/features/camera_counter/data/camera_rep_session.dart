import 'dart:async';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import '../domain/camera_counter.dart';
import 'camera_rep_device.dart';
import 'mlkit_pose_adapter.dart';

enum CameraRepSessionStatus { idle, running, paused, stopped }

class CameraRepResult {
  CameraRepResult._({
    required this.counter,
    required this.form,
    required this.status,
    required this.error,
    required this.mode,
  });

  final RepCounterResult counter;
  final FormCheckResult form;
  final CameraRepSessionStatus status;
  final String? error;
  int get repCount => counter.repCount;
  bool get personMissing => counter.personMissing;
  double get averageConfidence => counter.averageConfidence;
  int get formScore => form.formScore;
  List<FormIssue> get issues => form.issues;

  /// Chế độ của cấu hình đang chạy: reps (đếm lần) hoặc hold (giữ tư thế).
  /// UI hiện [repCount] khi reps, [holdDuration] khi hold.
  final CvMode mode;

  bool get isHold => mode == CvMode.hold;

  /// Thời gian giữ đúng tư thế (chỉ khác 0 ở chế độ hold). Không cộng khi
  /// ra khỏi dải góc, sai hướng thân, mất người hoặc tạm dừng.
  Duration get holdDuration => counter.holdDuration;

  /// Đang giữ đúng dải ở khung gần nhất (chế độ hold).
  bool get holding => counter.holding;

  /// Góc chính ở khung gần nhất (độ); null khi chưa có dữ liệu/mất người.
  double? get currentAngle => counter.currentAngle;

  /// Bên được dùng ở khung gần nhất; null khi lấy trung bình hai bên.
  BodySide? get selectedSide => counter.selectedSide;

  /// true khi góc là trung bình hai bên (`side: both`).
  bool get averagedSides => counter.averagedSides;

  /// false khi thân sai hướng (ví dụ đứng thẳng lúc plank); null nếu cấu
  /// hình không kiểm tra hướng hoặc chưa có dữ liệu.
  bool? get orientationOk => counter.orientationOk;
}

/// One set of any camera-supported exercise (reps or hold).
/// Subscribe before start; latestResult is also always readable.
///
/// start resumes after pause. pause releases the camera and cancels partial
/// motion while retaining completed reps. stop is terminal: drains in-flight
/// detection, closes ML Kit, releases camera, then closes the result stream.
class CameraRepSession {
  CameraRepSession({
    required this.config,
    CameraRepDevice? camera,
    CameraRepPoseDetector? detector,
    Duration Function()? elapsed,
    this.presenceInterval = const Duration(milliseconds: 100),
  }) : _counter = RepCounter(config: config),
       _camera = camera ?? FrontCameraRepDevice(),
       _detector = detector ?? MlkitStreamPoseDetector(),
       _elapsedOverride = elapsed {
    if (presenceInterval <= Duration.zero) {
      throw ArgumentError('presenceInterval must be positive');
    }
    _latest = _snapshot();
  }

  final Duration presenceInterval;

  /// Cấu hình đang dùng; UI xem `config.mode` để hiển thị số lần hay thời gian.
  final CvConfig config;
  final RepCounter _counter;
  final CameraRepDevice _camera;
  final CameraRepPoseDetector _detector;
  final Duration Function()? _elapsedOverride;
  final Stopwatch _clock = Stopwatch();
  final _results = StreamController<CameraRepResult>.broadcast();
  final _adapter = const MlkitPoseAdapter();
  final _formChecker = const FormChecker();
  late CameraRepResult _latest;
  CameraRepSessionStatus _status = CameraRepSessionStatus.idle;
  String? _error;
  Timer? _presenceTimer;
  Future<void> _operations = Future.value();
  Future<void>? _processing;
  Future<void>? _stopFuture;
  bool _acceptFrames = false;
  bool _stopping = false;
  int _generation = 0;
  Duration _lastDomainTime = Duration.zero;

  Stream<CameraRepResult> get results => _results.stream;
  CameraRepResult get latestResult => _latest;
  CameraController? get cameraController => _camera.controller;

  Future<void> start() {
    final generation = _generation;
    return _enqueue(() => _start(generation));
  }

  Future<void> _start(int generation) async {
    if (_stopping) throw StateError('Create a new session after stop');
    if (generation != _generation) return;
    if (_status == CameraRepSessionStatus.running) return;
    try {
      await _camera.initialize();
      if (_stopping || generation != _generation) return;
      _clock.start();
      _error = null;
      _acceptFrames = true;
      await _camera.startImages(
        (image) => _onImage(image, generation),
        (error, stack) => _onFrameError(error, generation),
      );
      if (_stopping || generation != _generation) return;
      _status = CameraRepSessionStatus.running;
      _presenceTimer = Timer.periodic(presenceInterval, (_) {
        if (!_acceptFrames) return;
        _counter.checkPresence(_timestamp());
        _publish();
      });
      _publish();
    } catch (error) {
      _suspendFrames();
      await _processing;
      await _camera.dispose();
      _status = CameraRepSessionStatus.paused;
      _error = error.toString();
      _publish();
      rethrow;
    }
  }

  Future<void> pause() {
    _suspendFrames();
    return _enqueue(() async {
      if (_stopping || _status == CameraRepSessionStatus.stopped) return;
      try {
        await _camera.stopImages();
      } finally {
        await _processing;
        await _camera.dispose();
        _counter.discardIncompleteRep();
        _status = CameraRepSessionStatus.paused;
        _publish();
      }
    });
  }

  Future<void> stop() {
    if (_stopFuture != null) return _stopFuture!;
    _stopping = true;
    _suspendFrames();
    _stopFuture = _enqueue(() async {
      try {
        await _camera.stopImages();
      } finally {
        await _processing;
        try {
          await _camera.dispose();
        } finally {
          try {
            await _detector.close();
          } finally {
            _clock.stop();
            _counter.discardIncompleteRep();
            _status = CameraRepSessionStatus.stopped;
            _publish();
            await _results.close();
          }
        }
      }
    });
    return _stopFuture!;
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next = _operations.then((_) => operation());
    // A failed start/pause must not prevent a later cleanup operation.
    _operations = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  void _suspendFrames() {
    _acceptFrames = false;
    _generation++;
    _presenceTimer?.cancel();
    _presenceTimer = null;
  }

  Duration get _elapsed => _elapsedOverride?.call() ?? _clock.elapsed;

  Duration _timestamp({bool frame = false}) {
    var timestamp = _elapsed;
    if (timestamp < _lastDomainTime ||
        (frame && timestamp == _lastDomainTime)) {
      timestamp = _lastDomainTime + const Duration(microseconds: 1);
    }
    _lastDomainTime = timestamp;
    return timestamp;
  }

  void _onImage(mlkit.InputImage image, int generation) {
    // No queue: drop new buffers until native inference finishes.
    if (!_acceptFrames || generation != _generation || _processing != null) {
      return;
    }
    _processing = _process(image, generation, _elapsed);
  }

  Future<void> _process(
    mlkit.InputImage image,
    int generation,
    Duration startedAt,
  ) async {
    try {
      final poses = await _detector.processImage(image);
      if (!_acceptFrames || generation != _generation) return;
      // A very slow result must not make a stale person look present again.
      if (_elapsed - startedAt > RepCounter.personMissingAfter) return;
      // Timestamp at delivery, after await: a timer may have advanced domain.
      _counter.addFrame(
        _adapter.toFrame(
          poses.isEmpty ? null : poses.first,
          timestamp: _timestamp(frame: true),
        ),
      );
      _error = null;
      _publish();
    } catch (error) {
      _onFrameError(error, generation);
    } finally {
      _processing = null;
    }
  }

  void _onFrameError(Object error, int generation) {
    if (!_acceptFrames || generation != _generation) return;
    _error = error.toString();
    _publish();
  }

  CameraRepResult _snapshot() => CameraRepResult._(
    counter: _counter.result,
    form: _formChecker.check(config, _counter.result),
    status: _status,
    error: _error,
    mode: config.mode,
  );

  void _publish() {
    _latest = _snapshot();
    if (!_results.isClosed) _results.add(_latest);
  }
}
