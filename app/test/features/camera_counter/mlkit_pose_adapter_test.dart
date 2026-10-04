import 'package:fitness_app/features/camera_counter/data/mlkit_pose_adapter.dart';
import 'package:fitness_app/features/camera_counter/domain/pose.dart';
import 'package:fitness_app/features/camera_counter/domain/rep_counter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart'
    as mlkit;

import 'synthetic_pose.dart';

mlkit.Pose fakePose({double confidence = 0.9}) => mlkit.Pose(
  landmarks: {
    for (final type in mlkit.PoseLandmarkType.values)
      type: mlkit.PoseLandmark(
        type: type,
        x: 100.25 + type.index,
        y: 200.5 - type.index,
        z: 50,
        likelihood: confidence,
      ),
  },
);

void main() {
  const adapter = MlkitPoseAdapter();

  test('maps all sixteen body joints (incl. elbow, wrist, heel, footIndex), preserving pixels, likelihood and time', () {
    final pose = fakePose();
    const timestamp = Duration(milliseconds: 234);
    final frame = adapter.toFrame(pose, timestamp: timestamp);
    expect(frame.timestamp, timestamp);
    expect(frame.landmarks.length, 16);
    for (final type in PoseLandmarkType.values) {
      final sourceType = mlkit.PoseLandmarkType.values.byName(type.name);
      final source = pose.landmarks[sourceType]!;
      final actual = frame.landmarks[type]!;
      expect(actual.type, type);
      expect(actual.x, source.x);
      expect(actual.y, source.y);
      expect(actual.likelihood, source.likelihood);
    }
  });

  test('missing joints are absent rather than fabricated or mirrored', () {
    final pose = fakePose();
    pose.landmarks.remove(mlkit.PoseLandmarkType.rightKnee);
    pose.landmarks.remove(mlkit.PoseLandmarkType.leftHip);
    final frame = adapter.toFrame(pose, timestamp: Duration.zero);
    expect(frame.landmarks.length, 14);
    expect(frame.landmarks.containsKey(PoseLandmarkType.rightKnee), isFalse);
    expect(frame.landmarks.containsKey(PoseLandmarkType.leftHip), isFalse);
  });

  test('retains low likelihood so RepCounter can reject the frame', () {
    final frame = adapter.toFrame(
      fakePose(confidence: 0.2),
      timestamp: Duration.zero,
    );
    expect(frame.landmarks.length, 16);
    expect(
      frame.landmarks.values.map((point) => point.likelihood),
      everyElement(0.2),
    );
    final result = RepCounter(config: squatConfig()).addFrame(frame);
    expect(result.repCount, 0);
    expect(result.currentAngle, isNull);
    expect(result.averageConfidence, 0);
  });

  test('no person and empty poses produce empty frames', () {
    expect(adapter.toFrame(null, timestamp: Duration.zero).landmarks, isEmpty);
    expect(
      adapter
          .toFrame(mlkit.Pose(landmarks: {}), timestamp: Duration.zero)
          .landmarks,
      isEmpty,
    );
  });

  test('frames remain independent of mutable ML Kit maps', () {
    final pose = fakePose();
    final frame = adapter.toFrame(pose, timestamp: Duration.zero);
    pose.landmarks.clear();
    expect(frame.landmarks.length, 16);
  });
}
