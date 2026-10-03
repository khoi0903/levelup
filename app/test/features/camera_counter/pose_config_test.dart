import 'dart:convert';

import 'package:fitness_app/features/camera_counter/domain/cv_config.dart';
import 'package:fitness_app/features/camera_counter/domain/joint_angle.dart';
import 'package:fitness_app/features/camera_counter/domain/pose.dart';
import 'package:flutter_test/flutter_test.dart';

PoseLandmark point(double x, double y) =>
    PoseLandmark(type: PoseLandmarkType.leftKnee, x: x, y: y, likelihood: 1);

void main() {
  group('jointAngle', () {
    test('returns 90, 180 and 0 degrees', () {
      expect(jointAngle(point(0, 1), point(0, 0), point(1, 0)), 90);
      expect(jointAngle(point(-1, 0), point(0, 0), point(1, 0)), 180);
      expect(jointAngle(point(1, 0), point(0, 0), point(2, 0)), 0);
    });

    test('is independent of translation and scale', () {
      expect(jointAngle(point(10, 30), point(10, 10), point(30, 10)), 90);
      expect(jointAngle(point(0, 1e200), point(0, 0), point(1e200, 0)), 90);
      expect(jointAngle(point(0, 1e-200), point(0, 0), point(1e-200, 0)), 90);
    });

    test('rejects coincident or nonfinite coordinates', () {
      expect(jointAngle(point(0, 0), point(0, 0), point(1, 0)), isNull);
      expect(jointAngle(point(1, 0), point(0, 0), point(0, 0)), isNull);
      expect(
        jointAngle(point(double.nan, 0), point(0, 0), point(1, 0)),
        isNull,
      );
      expect(
        jointAngle(point(1, 0), point(0, 0), point(double.infinity, 0)),
        isNull,
      );
    });
  });

  group('CvConfig', () {
    Map<String, dynamic> configJson() => jsonDecode(
      '{"joints":["hip","knee","ankle"],"downBelow":95,'
      '"upAbove":160,"minConfidence":0.6,"minRepMs":600}',
    ) as Map<String, dynamic>;

    test('reads exercise JSON and round trips', () {
      final config = CvConfig.fromJson(configJson());
      expect(config.joints, [PoseJoint.hip, PoseJoint.knee, PoseJoint.ankle]);
      expect(config.downBelow, 95);
      expect(config.upAbove, 160);
      expect(config.minConfidence, 0.6);
      expect(config.minRepMs, 600);
      expect(config.toJson(), configJson());
      expect(
        () => config.joints.add(PoseJoint.shoulder),
        throwsUnsupportedError,
      );
    });

    test('rejects malformed JSON and unsafe thresholds', () {
      for (final override in <Map<String, dynamic>>[
        {
          'joints': ['hip', 'unknown', 'ankle'],
        },
        {
          'joints': ['hip', 'hip', 'ankle'],
        },
        {
          'joints': ['hip', 'knee'],
        },
        {'downBelow': 160},
        {'downBelow': 0},
        {'upAbove': 180},
        {'upAbove': double.nan},
        {'minConfidence': 1.1},
        {'minConfidence': -0.1},
        {'minConfidence': double.infinity},
        {'minRepMs': -1},
        {'minRepMs': 600.5},
        {'minRepMs': '600'},
        {'downBelow': null},
      ]) {
        expect(
          () => CvConfig.fromJson({...configJson(), ...override}),
          throwsFormatException,
          reason: '$override',
        );
      }
    });
  });

  test('PoseFrame owns an immutable landmark index', () {
    final landmarks = [point(1, 2)];
    final frame = PoseFrame(timestamp: Duration.zero, landmarks: landmarks);
    landmarks.clear();
    expect(frame.landmarks[PoseLandmarkType.leftKnee]!.x, 1);
    expect(() => frame.landmarks.clear(), throwsUnsupportedError);
    expect(
      () => PoseFrame(
        timestamp: Duration.zero,
        landmarks: [point(1, 2), point(3, 4)],
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          PoseFrame(timestamp: const Duration(milliseconds: -1), landmarks: []),
      throwsArgumentError,
    );
  });
}
