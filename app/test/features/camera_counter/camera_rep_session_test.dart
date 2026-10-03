import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:fitness_app/features/camera_counter/data/camera_rep_device.dart';
import 'package:fitness_app/features/camera_counter/data/camera_rep_session.dart';
import 'package:fitness_app/features/camera_counter/domain/pose.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import 'synthetic_pose.dart';

mlkit.InputImage image() => mlkit.InputImage.fromBytes(
  bytes: Uint8List(6),
  metadata: mlkit.InputImageMetadata(
    size: const Size(2, 2),
    rotation: mlkit.InputImageRotation.rotation0deg,
    format: mlkit.InputImageFormat.nv21,
    bytesPerRow: 2,
  ),
);

mlkit.Pose pose(double angle) => mlkit.Pose(
  landmarks: {
    for (final point in sideLandmarks(BodySide.left, angle, 0.9))
      mlkit.PoseLandmarkType.values.byName(point.type.name): mlkit.PoseLandmark(
        type: mlkit.PoseLandmarkType.values.byName(point.type.name),
        x: point.x,
        y: point.y,
        z: 0,
        likelihood: point.likelihood,
      ),
  },
);

class FakeCamera implements CameraRepDevice {
  void Function(mlkit.InputImage)? onImage;
  void Function(Object, StackTrace)? onError;
  Completer<void>? initialization;
  Object? initializeError;
  Object? stopError;
  int initialized = 0;
  int started = 0;
  int disposed = 0;
  int stopped = 0;

  @override
  CameraController? get controller => null;

  @override
  Future<void> initialize() async {
    initialized++;
    if (initializeError != null) throw initializeError!;
    await initialization?.future;
  }

  @override
  Future<void> startImages(
    void Function(mlkit.InputImage) onImage,
    void Function(Object, StackTrace) onError,
  ) async {
    started++;
    this.onImage = onImage;
    this.onError = onError;
  }

  @override
  Future<void> stopImages() async {
    stopped++;
    if (stopError != null) throw stopError!;
  }

  @override
  Future<void> dispose() async {
    disposed++;
  }

  void emit() => onImage?.call(image());
}

class FakeDetector implements CameraRepPoseDetector {
  List<mlkit.Pose> poses = [];
  Completer<List<mlkit.Pose>>? pending;
  Object? error;
  int calls = 0;
  int closed = 0;

  @override
  Future<List<mlkit.Pose>> processImage(mlkit.InputImage image) async {
    calls++;
    if (error != null) throw error!;
    return pending == null ? poses : await pending!.future;
  }

  @override
  Future<void> close() async {
    closed++;
  }
}

void main() {
  testWidgets(
    'broadcast results contain reps, presence, form score and issues',
    (tester) async {
      final camera = FakeCamera();
      final detector = FakeDetector();
      var time = Duration.zero;
      final session = CameraRepSession(
        config: squatConfig(downBelow: 120),
        camera: camera,
        detector: detector,
        elapsed: () => time,
      );
      final seen = <CameraRepResult>[];
      session.results.listen(seen.add);
      session.results.listen((_) {});
      await session.start();
      Future<void> feed(double angle) async {
        detector.poses = [pose(angle)];
        camera.emit();
        await tester.pump();
        time += const Duration(milliseconds: 100);
      }

      await feed(170);
      await feed(175);
      for (var i = 0; i < 3; i++) {
        for (final angle in [
          140.0,
          115.0,
          110.0,
          105.0,
          125.0,
          140.0,
          150.0,
          170.0,
          175.0,
        ]) {
          await feed(angle);
        }
      }
      expect(session.latestResult.repCount, 3);
      expect(session.latestResult.personMissing, isFalse);
      expect(session.latestResult.formScore, 90);
      expect(
        session.latestResult.issues.map((issue) => issue.code),
        everyElement('shallow_depth'),
      );
      expect(session.latestResult.averageConfidence, closeTo(0.9, 1e-12));
      expect(seen.last.repCount, 3);
      final stopped = session.stop();
      await tester.pump();
      await stopped;
      expect(camera.disposed, 1);
      expect(detector.closed, 1);
    },
  );

  testWidgets('drops new frames while detection is in flight', (tester) async {
    final camera = FakeCamera();
    final detector = FakeDetector()..pending = Completer();
    final session = CameraRepSession(
      config: squatConfig(),
      camera: camera,
      detector: detector,
    );
    await session.start();
    camera.emit();
    camera.emit();
    camera.emit();
    expect(detector.calls, 1);
    detector.pending!.complete([pose(170)]);
    await tester.pump();
    detector.pending = null;
    camera.emit();
    await tester.pump();
    expect(detector.calls, 2);
    final stopped = session.stop();
    await tester.pump();
    await stopped;
  });

  testWidgets(
    'timer advances presence while inference is pending; stale results are dropped',
    (tester) async {
      final camera = FakeCamera();
      final detector = FakeDetector()..pending = Completer();
      var time = Duration.zero;
      final session = CameraRepSession(
        config: squatConfig(),
        camera: camera,
        detector: detector,
        elapsed: () => time,
      );
      await session.start();
      camera.emit();
      time = const Duration(milliseconds: 1100);
      await tester.pump(const Duration(milliseconds: 100));
      expect(session.latestResult.personMissing, isTrue);
      detector.pending!.complete([pose(170)]);
      await tester.pump();
      expect(session.latestResult.personMissing, isTrue);
      detector.pending = null;
      detector.poses = [pose(170)];
      time = const Duration(milliseconds: 1200);
      camera.emit();
      await tester.pump();
      expect(session.latestResult.personMissing, isFalse);
      expect(session.latestResult.error, isNull);
      await session.stop();
    },
  );

  testWidgets(
    'timer and a faster inference completion share ordered timestamps',
    (tester) async {
      final camera = FakeCamera();
      final detector = FakeDetector()..pending = Completer();
      var time = Duration.zero;
      final session = CameraRepSession(
        config: squatConfig(),
        camera: camera,
        detector: detector,
        elapsed: () => time,
      );
      await session.start();
      camera.emit();
      time = const Duration(milliseconds: 200);
      await tester.pump(const Duration(milliseconds: 100));
      detector.pending!.complete([pose(170)]);
      await tester.pump();
      expect(session.latestResult.error, isNull);
      expect(session.latestResult.counter.currentAngle, closeTo(170, 1e-10));
      // Multiple frame deliveries at the same clock tick stay strictly ordered.
      detector.pending = null;
      detector.poses = [pose(175)];
      camera.emit();
      await tester.pump();
      expect(session.latestResult.error, isNull);
      await session.stop();
    },
  );

  testWidgets(
    'pause drains inference, releases camera, and discards the late pose',
    (tester) async {
      final camera = FakeCamera();
      final detector = FakeDetector()..pending = Completer();
      final session = CameraRepSession(
        config: squatConfig(),
        camera: camera,
        detector: detector,
      );
      await session.start();
      camera.emit();
      final paused = session.pause();
      await tester.pump();
      expect(camera.disposed, 0);
      detector.pending!.complete([pose(80)]);
      await tester.pump();
      await paused;
      expect(camera.disposed, 1);
      expect(detector.closed, 0);
      expect(session.latestResult.status, CameraRepSessionStatus.paused);
      expect(session.latestResult.averageConfidence, 0);
      detector.pending = null;
      await session.start();
      expect(camera.initialized, 2);
      expect(camera.started, 2);
      await session.stop();
    },
  );

  testWidgets('a quick pause cannot bridge a partial squat', (tester) async {
    final camera = FakeCamera();
    final detector = FakeDetector();
    var time = Duration.zero;
    final session = CameraRepSession(
      config: squatConfig(minRepMs: 0),
      camera: camera,
      detector: detector,
      elapsed: () => time,
    );
    await session.start();
    Future<void> feed(double angle) async {
      time += const Duration(milliseconds: 50);
      detector.poses = [pose(angle)];
      camera.emit();
      await tester.pump();
    }

    for (final angle in [170.0, 175.0, 90.0, 80.0, 170.0, 175.0]) {
      await feed(angle);
    }
    expect(session.latestResult.repCount, 1);
    await feed(90);
    await feed(80);
    await session.pause();
    await session.start();
    await feed(170);
    await feed(175);
    expect(session.latestResult.repCount, 1);
    for (final angle in [90.0, 80.0, 170.0, 175.0]) {
      await feed(angle);
    }
    expect(session.latestResult.repCount, 2);
    await session.stop();
  });

  testWidgets(
    'stop waits for inference before closing detector and result stream',
    (tester) async {
      final camera = FakeCamera();
      final detector = FakeDetector()..pending = Completer();
      final session = CameraRepSession(
        config: squatConfig(),
        camera: camera,
        detector: detector,
      );
      var done = false;
      session.results.listen(
        (_) {},
        onDone: () => done = true,
      );
      await session.start();
      camera.emit();
      final stopped = session.stop();
      camera.emit();
      await tester.pump();
      expect(detector.calls, 1);
      expect(detector.closed, 0);
      detector.pending!.complete([pose(170)]);
      await tester.pump();
      await stopped;
      expect(done, isTrue);
      expect(detector.closed, 1);
      expect(camera.disposed, 1);
      expect(session.latestResult.status, CameraRepSessionStatus.stopped);
      expect(session.latestResult.averageConfidence, 0);
      await session.stop();
      expect(detector.closed, 1);
      await expectLater(session.start(), throwsStateError);
    },
  );

  testWidgets(
    'pause requested during camera initialization prevents streaming',
    (tester) async {
      final camera = FakeCamera()..initialization = Completer();
      final detector = FakeDetector();
      final session = CameraRepSession(
        config: squatConfig(),
        camera: camera,
        detector: detector,
      );
      final started = session.start();
      await tester.pump();
      final paused = session.pause();
      camera.initialization!.complete();
      await tester.pump();
      await started;
      await paused;
      expect(camera.started, 0);
      expect(camera.disposed, 1);
      expect(session.latestResult.status, CameraRepSessionStatus.paused);
      await session.stop();
    },
  );

  testWidgets(
    'stop requested during initialization still releases all resources',
    (tester) async {
      final camera = FakeCamera()..initialization = Completer();
      final detector = FakeDetector();
      final session = CameraRepSession(
        config: squatConfig(),
        camera: camera,
        detector: detector,
      );
      final started = session.start();
      await tester.pump();
      final stopped = session.stop();
      camera.initialization!.complete();
      await tester.pump();
      await started;
      await stopped;
      expect(camera.started, 0);
      expect(camera.disposed, 1);
      expect(detector.closed, 1);
    },
  );

  testWidgets(
    'denied camera access is surfaced; stop still closes the detector',
    (tester) async {
      final camera = FakeCamera()
        ..initializeError = CameraException('CameraAccessDenied', 'Denied');
      final detector = FakeDetector();
      final session = CameraRepSession(
        config: squatConfig(),
        camera: camera,
        detector: detector,
      );
      await expectLater(session.start(), throwsA(isA<CameraException>()));
      expect(session.latestResult.error, contains('CameraAccessDenied'));
      expect(session.latestResult.status, CameraRepSessionStatus.paused);
      await session.stop();
      expect(detector.closed, 1);
    },
  );

  testWidgets('inference errors release busy state and allow the next frame', (
    tester,
  ) async {
    final camera = FakeCamera();
    final detector = FakeDetector()..error = StateError('Inference failed');
    final session = CameraRepSession(
      config: squatConfig(),
      camera: camera,
      detector: detector,
    );
    await session.start();
    camera.emit();
    await tester.pump();
    expect(session.latestResult.error, contains('Inference failed'));
    detector.error = null;
    detector.poses = [pose(170)];
    camera.emit();
    await tester.pump();
    expect(session.latestResult.error, isNull);
    expect(detector.calls, 2);
    await session.stop();
  });

  testWidgets(
    'stop frees resources even when stopping the image stream fails',
    (tester) async {
      final camera = FakeCamera()..stopError = StateError('Stream stop failed');
      final detector = FakeDetector();
      final session = CameraRepSession(
        config: squatConfig(),
        camera: camera,
        detector: detector,
      );
      await session.start();
      await expectLater(session.stop(), throwsStateError);
      expect(camera.disposed, 1);
      expect(detector.closed, 1);
      expect(session.latestResult.status, CameraRepSessionStatus.stopped);
    },
  );
}
