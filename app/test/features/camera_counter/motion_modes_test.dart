import 'package:fitness_app/features/camera_counter/domain/camera_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_pose.dart';

CvConfig motionConfig({
  CvMode mode = CvMode.alternating,
  CvDirection direction = CvDirection.flex,
  int minRepMs = 200,
}) => CvConfig.fromJson({
  'mode': mode.name,
  'direction': direction.name,
  'joints': ['hip', 'knee', 'ankle'],
  'downBelow': 100,
  'upAbove': 150,
  'minConfidence': 0.5,
  'minRepMs': minRepMs,
});

class MotionFeeder extends FrameFeeder {
  MotionFeeder(super.config);

  RepCounterResult sides(
    double left,
    double right, {
    double leftConfidence = 0.9,
    double rightConfidence = 0.8,
    int stepMs = 100,
  }) => add(
    triplet(counter.config.joints, left),
    right: triplet(counter.config.joints, right),
    leftConfidence: leftConfidence,
    rightConfidence: rightConfidence,
    stepMs: stepMs,
  );

  double get rest => counter.config.direction == CvDirection.flex ? 170 : 80;
  double get active => counter.config.direction == CvDirection.flex ? 80 : 170;

  void armBoth() {
    sides(rest, rest);
    sides(rest, rest);
  }

  void cycle(BodySide side) {
    for (final angle in [active, active, active, rest, rest]) {
      sides(
        side == BodySide.left ? angle : rest,
        side == BodySide.right ? angle : rest,
      );
    }
  }
}

void main() {
  for (final direction in CvDirection.values) {
    group('alternating ${direction.name}', () {
      test(
        'three left and three right cycles count six with unequal confidence',
        () {
          final f = MotionFeeder(motionConfig(direction: direction))..armBoth();
          for (var i = 0; i < 3; i++) {
            f.cycle(BodySide.left);
            f.cycle(BodySide.right);
          }
          expect(f.counter.result.repCount, 6);
          expect(f.counter.result.reps.map((rep) => rep.repIndex), [
            1,
            2,
            3,
            4,
            5,
            6,
          ]);
          expect(
            f.counter.result.reps.every(
              (rep) => rep.duration == const Duration(milliseconds: 300),
            ),
            isTrue,
          );
          expect(f.counter.result.holdDuration, Duration.zero);
        },
      );

      test(
        'simultaneous cycles count once; staggered returns also count once',
        () {
          final f = MotionFeeder(motionConfig(direction: direction))..armBoth();
          for (var i = 0; i < 3; i++) {
            f.sides(f.active, f.active);
          }
          f.sides(f.rest, f.rest);
          f.sides(f.rest, f.rest);
          expect(f.counter.result.repCount, 1);
          f.sides(f.active, f.active);
          f.sides(f.active, f.active);
          f.sides(f.active, f.active);
          f.sides(f.rest, f.active);
          f.sides(f.rest, f.active);
          f.sides(f.rest, f.rest);
          f.sides(f.rest, f.rest);
          expect(f.counter.result.repCount, 2);
          f.cycle(BodySide.right);
          expect(f.counter.result.repCount, 3);
        },
      );

      test('jitter and single-frame crossings cannot count', () {
        final f = MotionFeeder(motionConfig(direction: direction))..armBoth();
        final threshold = direction == CvDirection.flex ? 100.0 : 150.0;
        for (var i = 0; i < 20; i++) {
          f.sides(threshold - 1, threshold + 1);
          f.sides(threshold + 1, threshold - 1);
        }
        f.sides(f.rest, f.rest);
        f.sides(f.rest, f.rest);
        expect(f.counter.result.repCount, 0);
      });

      test(
        'starting active, short cycles and paused partials do not count',
        () {
          final f = MotionFeeder(
            motionConfig(direction: direction, minRepMs: 400),
          );
          f.sides(f.active, f.active);
          f.sides(f.active, f.active);
          f.armBoth();
          expect(f.counter.result.repCount, 0);
          f.cycle(BodySide.left); // Only 300 ms.
          expect(f.counter.result.repCount, 0);
          f.sides(f.active, f.rest);
          f.sides(f.active, f.rest);
          f.counter.discardIncompleteRep();
          f.armBoth();
          expect(f.counter.result.repCount, 0);
        },
      );

      test('a missing opposite side does not prevent a full visible cycle', () {
        final f = MotionFeeder(motionConfig(direction: direction));
        for (final angle in [
          f.rest,
          f.rest,
          f.active,
          f.active,
          f.active,
          f.rest,
          f.rest,
        ]) {
          f.sides(angle, f.rest, rightConfidence: 0.1);
        }
        expect(f.counter.result.repCount, 1);
      });
    });
  }

  group('active duration', () {
    test('static and jittering poses never start the clock', () {
      final f = MotionFeeder(motionConfig(mode: CvMode.active))..armBoth();
      for (var i = 0; i < 30; i++) {
        f.sides(149, 151);
        f.sides(151, 149);
      }
      expect(f.counter.result.holding, isFalse);
      expect(f.counter.result.holdDuration, Duration.zero);
    });

    test(
      'cycles run the clock; stationary frames stop it exactly after 2 seconds',
      () {
        final f = MotionFeeder(motionConfig(mode: CvMode.active))..armBoth();
        f.cycle(BodySide.left);
        expect(f.counter.result.holding, isTrue);
        expect(f.counter.result.holdDuration, Duration.zero);
        f.cycle(BodySide.right);
        expect(
          f.counter.result.holdDuration,
          const Duration(milliseconds: 500),
        );
        for (var i = 0; i < 19; i++) {
          f.sides(f.rest, f.rest);
        }
        expect(f.counter.result.holding, isTrue);
        f.sides(f.rest, f.rest);
        expect(f.counter.result.holding, isFalse);
        expect(
          f.counter.result.holdDuration,
          const Duration(milliseconds: 2500),
        );
        f.sides(f.rest, f.rest);
        expect(
          f.counter.result.holdDuration,
          const Duration(milliseconds: 2500),
        );
        expect(f.counter.result.repCount, 0);
        f.cycle(BodySide.left);
        expect(f.counter.result.holding, isTrue);
        expect(
          f.counter.result.holdDuration,
          const Duration(milliseconds: 2500),
        );
        f.sides(f.rest, f.rest);
        expect(
          f.counter.result.holdDuration,
          const Duration(milliseconds: 2600),
        );
      },
    );

    test(
      'expiry clips a frame interval instead of adding the whole interval',
      () {
        final f = MotionFeeder(motionConfig(mode: CvMode.active))..armBoth();
        f.cycle(BodySide.left);
        for (var i = 0; i < 6; i++) {
          f.sides(f.rest, f.rest, stepMs: 300);
        }
        f.sides(f.rest, f.rest, stepMs: 300);
        f.sides(f.rest, f.rest);
        expect(f.counter.result.holding, isFalse);
        expect(f.counter.result.holdDuration, const Duration(seconds: 2));
      },
    );

    test(
      'pause, missing person and unusable frames stop without losing time',
      () {
        final f = MotionFeeder(motionConfig(mode: CvMode.active))..armBoth();
        f.cycle(BodySide.left);
        f.sides(f.rest, f.rest);
        final before = f.counter.result.holdDuration;
        expect(f.counter.discardIncompleteRep().holding, isFalse);
        f.armBoth();
        expect(f.counter.result.holdDuration, before);
        expect(f.counter.result.holding, isFalse);
        f.cycle(BodySide.right);
        f.sides(f.rest, f.rest);
        final elapsed = f.counter.result.holdDuration;
        final missing = f.counter.checkPresence(
          Duration(milliseconds: f.nextMs + 1100),
        );
        expect(missing.personMissing, isTrue);
        expect(missing.holding, isFalse);
        expect(missing.holdDuration, elapsed);
        f.nextMs += 1200;
        f.armBoth();
        expect(f.counter.result.holding, isFalse);
        f.cycle(BodySide.left);
        f.sides(f.rest, f.rest, leftConfidence: 0.1, rightConfidence: 0.1);
        expect(f.counter.result.holding, isFalse);
      },
    );

    test('gaps longer than 500 ms do not add unobserved time', () {
      final f = MotionFeeder(motionConfig(mode: CvMode.active))..armBoth();
      f.cycle(BodySide.left);
      f.sides(f.rest, f.rest, stepMs: 600);
      final before = f.counter.result.holdDuration;
      f.sides(f.rest, f.rest);
      expect(f.counter.result.holdDuration, before);
    });

    test('overlapping cycles refresh activity through the later return', () {
      final f = MotionFeeder(motionConfig(mode: CvMode.active))..armBoth();
      for (var i = 0; i < 3; i++) {
        f.sides(f.active, f.active);
      }
      f.sides(f.rest, f.active);
      f.sides(f.rest, f.active);
      f.sides(f.rest, f.rest);
      f.sides(f.rest, f.rest);
      for (var i = 0; i < 19; i++) {
        f.sides(f.rest, f.rest);
      }
      expect(f.counter.result.holding, isTrue);
      f.sides(f.rest, f.rest);
      expect(f.counter.result.holding, isFalse);
      expect(f.counter.result.holdDuration, const Duration(milliseconds: 2200));
      expect(f.counter.result.repCount, 0);
    });

    test('extend cycles also activate duration', () {
      final f = MotionFeeder(
        motionConfig(mode: CvMode.active, direction: CvDirection.extend),
      )..armBoth();
      f.cycle(BodySide.right);
      expect(f.counter.result.holding, isTrue);
      f.sides(f.rest, f.rest);
      expect(f.counter.result.holdDuration, const Duration(milliseconds: 100));
    });

    test('duration band rules grade moving time', () {
      final config = CvConfig.fromJson({
        ...motionConfig(mode: CvMode.active).toJson(),
        'formRules': [
          {
            'type': 'band',
            'code': 'bad_posture',
            'min': 160,
            'max': 180,
            'severity': [0.25, 0.5],
          },
        ],
      });
      final f = MotionFeeder(config)..armBoth();
      f.cycle(BodySide.left);
      for (var i = 0; i < 10; i++) {
        f.sides(130, 130);
      }
      expect(f.counter.result.holdDuration, const Duration(seconds: 1));
      final form = const FormChecker().check(config, f.counter.result);
      expect(form.formScore, 70);
      expect(form.issues.single.code, 'bad_posture');
    });
  });

  test(
    'alternating grades the completing side, preserving immutable snapshots',
    () {
      final config = CvConfig.fromJson({
        ...motionConfig().toJson(),
        'formRules': [
          {
            'type': 'min_depth',
            'code': 'shallow_motion',
            'angle': 75,
            'severity': [85, 95],
          },
        ],
      });
      final f = MotionFeeder(config)..armBoth();
      f.cycle(BodySide.right);
      final first = f.counter.result;
      final form = const FormChecker().check(config, first);
      expect(first.reps.single.deepestAngle, closeTo(80, 1e-9));
      expect(form.issues.single.severity, 1);
      f.cycle(BodySide.left);
      expect(first.repCount, 1);
      expect(f.counter.result.repCount, 2);
    },
  );

  for (final mode in [CvMode.alternating, CvMode.active]) {
    test(
      '${mode.name}: wrong orientation remains person present and cancels motion',
      () {
        final config = CvConfig.fromJson({
          ...motionConfig(mode: mode).toJson(),
          'orientation': {
            'joints': ['hip', 'knee'],
            'axis': 'vertical',
          },
        });
        final f = MotionFeeder(config)
          ..armBoth(); // Synthetic hip/knee is horizontal.
        for (var i = 0; i < 4; i++) {
          f.cycle(BodySide.left);
        }
        expect(f.counter.result.orientationOk, isFalse);
        expect(f.counter.result.personMissing, isFalse);
        expect(f.counter.result.repCount, 0);
        expect(f.counter.result.holdDuration, Duration.zero);
        expect(f.counter.result.holding, isFalse);
      },
    );
  }

  for (final slug in [
    'dead-bug',
    'bird-dog',
    'march-in-place',
    'step-jack',
    'dumbbell-floor-press',
  ]) {
    test(
      '$slug: its JSON config processes a full cycle and grades good form',
      () {
        final config = exerciseConfig(slug);
        final f = FrameFeeder(config);
        Map<PoseJoint, Point> points(double angle) {
          switch (slug) {
            case 'dead-bug':
              const Point hip = (0, 0);
              const Point knee = (0, -1);
              return {
                PoseJoint.shoulder: (-2, 0),
                PoseJoint.hip: hip,
                PoseJoint.knee: knee,
                PoseJoint.ankle: bend(hip, knee, angle),
              };
            case 'bird-dog':
              return triplet(config.joints, angle);
            case 'march-in-place':
              const Point hip = (0, 0);
              const Point knee = (0, 1);
              return {
                PoseJoint.shoulder: (0, -1),
                PoseJoint.hip: hip,
                PoseJoint.knee: knee,
                PoseJoint.ankle: bend(hip, knee, angle),
              };
            case 'step-jack':
              const Point hip = (0, 1);
              const Point shoulder = (0, 0);
              final elbow = bend(hip, shoulder, angle);
              return {
                PoseJoint.hip: hip,
                PoseJoint.shoulder: shoulder,
                PoseJoint.elbow: elbow,
                PoseJoint.wrist: bend(shoulder, elbow, 175),
              };
            default:
              const Point shoulder = (0, 0);
              const Point elbow = (0, 1);
              return {
                PoseJoint.hip: (-2, 0),
                PoseJoint.shoulder: shoulder,
                PoseJoint.elbow: elbow,
                PoseJoint.wrist: bend(shoulder, elbow, angle),
              };
          }
        }

        final rest = config.direction == CvDirection.flex ? 170.0 : 30.0;
        // Leg/press rest is a bent joint, unlike step-jack's lowered arm.
        final restAngle =
            config.direction == CvDirection.extend && slug != 'step-jack'
            ? 90.0
            : rest;
        final active = config.direction == CvDirection.flex ? 90.0 : 175.0;
        f.add(points(restAngle), stepMs: 200);
        f.add(points(restAngle), stepMs: 200);
        for (final angle in [active, active, active, restAngle, restAngle]) {
          f.add(points(angle), stepMs: 200);
        }
        final cycle = f.counter.result;
        expect(cycle.orientationOk, isTrue);
        if (config.isHold) {
          expect(cycle.holding, isTrue);
          f.add(points(restAngle));
          expect(
            f.counter.result.holdDuration,
            const Duration(milliseconds: 200),
          );
        } else {
          expect(cycle.repCount, 1);
        }
        expect(
          const FormChecker().check(config, f.counter.result).issues,
          isEmpty,
        );
      },
    );
  }

  test(
    'new modes round trip and reject missing or invalid motion thresholds',
    () {
      for (final mode in [CvMode.alternating, CvMode.active]) {
        final config = motionConfig(mode: mode);
        expect(CvConfig.fromJson(config.toJson()).mode, mode);
        expect(config.isHold, mode == CvMode.active);
        expect(config.formRules, isEmpty);
        expect(
          () => CvConfig.fromJson({...config.toJson(), 'upAbove': 90}),
          throwsFormatException,
        );
        expect(
          () => CvConfig.fromJson({...config.toJson()}..remove('downBelow')),
          throwsFormatException,
        );
      }
      final active = motionConfig(mode: CvMode.active).toJson();
      expect(
        () => CvConfig.fromJson({
          ...active,
          'formRules': [
            {
              'type': 'max_extreme',
              'code': 'x',
              'angle': 160,
              'severity': [150, 140],
            },
          ],
        }),
        throwsFormatException,
      );
    },
  );
}
