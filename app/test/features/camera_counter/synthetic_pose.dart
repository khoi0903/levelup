import 'dart:math' as math;

import 'package:fitness_app/features/camera_counter/domain/cv_config.dart';
import 'package:fitness_app/features/camera_counter/domain/pose.dart';
import 'package:fitness_app/features/camera_counter/domain/rep_counter.dart';

CvConfig squatConfig({double downBelow = 95, int minRepMs = 600}) =>
    CvConfig.fromJson({
      'joints': ['hip', 'knee', 'ankle'],
      'downBelow': downBelow,
      'upAbove': 160,
      'minConfidence': 0.6,
      'minRepMs': minRepMs,
    });

/// Hip and ankle vectors have the requested angle around the knee.
List<PoseLandmark> sideLandmarks(
  BodySide side,
  double angle,
  double confidence,
) {
  final radians = angle * math.pi / 180;
  return [
    PoseLandmark(
      type: PoseLandmarkType.forJoint(PoseJoint.shoulder, side),
      x: 2,
      y: 0,
      likelihood: confidence,
    ),
    PoseLandmark(
      type: PoseLandmarkType.forJoint(PoseJoint.hip, side),
      x: 1,
      y: 0,
      likelihood: confidence,
    ),
    PoseLandmark(
      type: PoseLandmarkType.forJoint(PoseJoint.knee, side),
      x: 0,
      y: 0,
      likelihood: confidence,
    ),
    PoseLandmark(
      type: PoseLandmarkType.forJoint(PoseJoint.ankle, side),
      x: math.cos(radians),
      y: math.sin(radians),
      likelihood: confidence,
    ),
  ];
}

PoseFrame poseAt(
  int milliseconds, {
  double leftAngle = 170,
  double rightAngle = 170,
  double leftConfidence = 0.9,
  double rightConfidence = 0.8,
}) => PoseFrame(
  timestamp: Duration(milliseconds: milliseconds),
  landmarks: [
    ...sideLandmarks(BodySide.left, leftAngle, leftConfidence),
    ...sideLandmarks(BodySide.right, rightAngle, rightConfidence),
  ],
);

class SyntheticSession {
  SyntheticSession({CvConfig? config})
    : counter = RepCounter(config: config ?? squatConfig());

  final RepCounter counter;
  int nextMs = 0;

  RepCounterResult feed(
    double angle, {
    int stepMs = 100,
    double leftConfidence = 0.9,
    double rightConfidence = 0.8,
  }) {
    final result = counter.addFrame(
      poseAt(
        nextMs,
        leftAngle: angle,
        rightAngle: angle,
        leftConfidence: leftConfidence,
        rightConfidence: rightConfidence,
      ),
    );
    nextMs += stepMs;
    return result;
  }

  void arm() {
    feed(170);
    feed(175);
  }

  void squat({double deepestAngle = 80, bool insertLowConfidence = false}) {
    // Six hundred milliseconds from the first down to the first up frame.
    for (final angle in [
      140.0,
      deepestAngle + 10,
      deepestAngle + 5,
      deepestAngle,
      125.0,
      140.0,
      150.0,
      170.0,
      175.0,
    ]) {
      if (insertLowConfidence) {
        // Invalid frames deliberately contain a misleading deep angle.
        feed(20, leftConfidence: 0.2, rightConfidence: 0.3);
      }
      // Keep two adjacent reliable samples for each threshold confirmation.
      feed(angle);
      if (insertLowConfidence) feed(angle);
    }
  }
}
