import 'dart:async';

import 'package:fitness_app/features/camera_counter/data/camera_rep_session.dart';
import 'package:fitness_app/features/camera_counter/domain/cv_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import 'camera_rep_session_test.dart'
    show FakeCamera, FakeDetector, image, pose;

/// A native camera stream is shared across controller instances. A late
/// dispose can disconnect the next controller if it was initialized too soon.
class SharedCameraHardware {
  void Function(mlkit.InputImage)? stream;
  final cameras = <HandoffCamera>[];
  final detectors = <FakeDetector>[];
  Duration time = Duration.zero;

  CameraRepSession create(CvConfig config) {
    final camera = HandoffCamera(this);
    final detector = FakeDetector();
    cameras.add(camera);
    detectors.add(detector);
    return CameraRepSession(
      config: config,
      camera: camera,
      detector: detector,
      elapsed: () => time,
    );
  }

  Future<void> rep(WidgetTester tester, int index) async {
    for (final angle in [
      170.0,
      175.0,
      90.0,
      80.0,
      80.0,
      80.0,
      80.0,
      170.0,
      175.0,
    ]) {
      time += const Duration(milliseconds: 200);
      detectors[index].poses = [pose(angle)];
      stream?.call(image());
      await tester.pump();
    }
    // Inference publishes asynchronously; paint the mapped result on the UI.
    await tester.pump();
  }
}

class HandoffCamera extends FakeCamera {
  HandoffCamera(this.hardware);
  final SharedCameraHardware hardware;
  Completer<void>? release;

  @override
  Future<void> startImages(
    void Function(mlkit.InputImage) onImage,
    void Function(Object, StackTrace) onError,
  ) async {
    await super.startImages(onImage, onError);
    hardware.stream = onImage;
  }

  @override
  Future<void> dispose() async {
    await release?.future;
    hardware.stream = null;
    await super.dispose();
  }
}
