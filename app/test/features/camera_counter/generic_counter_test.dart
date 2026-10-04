import 'package:fitness_app/features/camera_counter/domain/camera_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_pose.dart';

Point rotate(Point p) => (-p.$2, p.$1);

/// Hít đất nhìn nghiêng: thân nằm ngang (hoặc dựng đứng khi [upright]),
/// góc khuỷu [elbow], góc thân vai–hông–cổ chân [body].
Map<PoseJoint, Point> pushUpPose(
  double elbow, {
  double body = 178,
  bool upright = false,
}) {
  const Point shoulder = (0, 0);
  const Point hip = (-5, 0);
  const Point elbowPoint = (0, 1);
  final points = {
    PoseJoint.shoulder: shoulder,
    PoseJoint.hip: hip,
    PoseJoint.ankle: bend(shoulder, hip, body, length: 5),
    PoseJoint.elbow: elbowPoint,
    PoseJoint.wrist: bend(shoulder, elbowPoint, elbow),
  };
  return upright
      ? points.map((joint, point) => MapEntry(joint, rotate(point)))
      : points;
}

/// Plank/thân người: vai–hông–cổ chân với góc ở hông [body].
Map<PoseJoint, Point> bodyLine(double body, {bool upright = false}) {
  const Point shoulder = (0, 0);
  const Point hip = (-5, 0);
  final points = {
    PoseJoint.shoulder: shoulder,
    PoseJoint.hip: hip,
    PoseJoint.ankle: bend(shoulder, hip, body, length: 5),
  };
  return upright
      ? points.map((joint, point) => MapEntry(joint, rotate(point)))
      : points;
}

void main() {
  group('direction flex (non-squat joints)', () {
    test('biceps curl elbow angle counts and grades depth', () {
      final feeder = FrameFeeder(exerciseConfig('dumbbell-biceps-curl'));
      feeder.angles([160, 165], stepMs: 200);
      for (final deepest in [50.0, 60.0, 66.0, 68.0]) {
        feeder.angles([120, deepest, deepest, 100, 150, 160], stepMs: 200);
      }
      final result = feeder.counter.result;
      expect(result.repCount, 4);
      expect(result.reps.map((rep) => rep.deepestAngle), [
        closeTo(50, 1e-9),
        closeTo(60, 1e-9),
        closeTo(66, 1e-9),
        closeTo(68, 1e-9),
      ]);
      final form = const FormChecker().check(feeder.counter.config, result);
      expect(form.issues.map((issue) => issue.toJson()), [
        {'repIndex': 2, 'code': 'curl_not_full_range', 'severity': 1},
        {'repIndex': 3, 'code': 'curl_not_full_range', 'severity': 2},
        {'repIndex': 4, 'code': 'curl_not_full_range', 'severity': 3},
      ]);
      expect(form.formScore, (100 - 60 / 4).round());
    });
  });

  group('direction extend', () {
    test('glute bridge counts rest → extended → rest', () {
      final feeder = FrameFeeder(exerciseConfig('glute-bridge'));
      feeder.angles([140, 138], stepMs: 200);
      for (var i = 0; i < 3; i++) {
        feeder.angles([155, 165, 172, 175, 165, 150, 140, 135], stepMs: 200);
      }
      final result = feeder.counter.result;
      expect(result.repCount, 3);
      expect(result.state, RepState.up);
      for (final rep in result.reps) {
        // First >162 frame (165) to first <150 frame (140).
        expect(rep.duration, const Duration(milliseconds: 1000));
        expect(rep.peakAngle, closeTo(175, 1e-9));
      }
      final form = const FormChecker().check(feeder.counter.config, result);
      expect(form.issues, isEmpty);
      expect(form.formScore, 100);
    });

    test('jitter around upAbove and staying at rest never count', () {
      final feeder = FrameFeeder(exerciseConfig('glute-bridge'));
      feeder.angles([140, 138]);
      for (var i = 0; i < 20; i++) {
        feeder.angles([161, 163]);
      }
      feeder.angles(List.filled(10, 140));
      expect(feeder.counter.result.repCount, 0);
    });

    test('starting in the extended position cannot count a partial rep', () {
      final feeder = FrameFeeder(exerciseConfig('glute-bridge'));
      feeder.angles([175, 175, 140, 135], stepMs: 200);
      expect(feeder.counter.result.repCount, 0);
      feeder.angles([165, 172, 175, 150, 140, 135], stepMs: 200);
      expect(feeder.counter.result.repCount, 1);
    });

    test('max_extreme grades a low peak with all three severities', () {
      final config = exerciseConfig('glute-bridge');
      final feeder = FrameFeeder(config);
      feeder.angles([140, 138], stepMs: 200);
      for (final peak in [175.0, 168.0, 165.0, 163.0]) {
        feeder.angles([155, peak, peak, peak, 140, 135], stepMs: 200);
      }
      final result = feeder.counter.result;
      expect(result.repCount, 4);
      final form = const FormChecker().check(config, result);
      expect(form.issues.map((issue) => issue.toJson()), [
        {'repIndex': 2, 'code': 'bridge_hips_not_high_enough', 'severity': 1},
        {'repIndex': 3, 'code': 'bridge_hips_not_high_enough', 'severity': 2},
        {'repIndex': 4, 'code': 'bridge_hips_not_high_enough', 'severity': 3},
      ]);
    });
  });

  group('side', () {
    final jack = exerciseConfig('jumping-jack');
    Map<PoseJoint, Point> arm(double angle) => triplet(jack.joints, angle);

    test('both averages the two sides and reports no single side', () {
      final feeder = FrameFeeder(jack);
      final result = feeder.add(arm(30), right: arm(20));
      expect(result.currentAngle, closeTo(25, 1e-9));
      expect(result.averagedSides, isTrue);
      expect(result.selectedSide, isNull);
    });

    test('both falls back to the only usable side', () {
      final feeder = FrameFeeder(jack);
      final result = feeder.add(arm(30), right: {});
      expect(result.currentAngle, closeTo(30, 1e-9));
      expect(result.averagedSides, isFalse);
      expect(result.selectedSide, BodySide.left);
    });

    test('both: one arm up alone is not a jumping jack', () {
      final feeder = FrameFeeder(jack);
      feeder.add(arm(30), right: arm(30));
      feeder.add(arm(30), right: arm(30));
      for (var i = 0; i < 5; i++) {
        // Mean 105 stays under upAbove=110.
        feeder.add(arm(170), right: arm(40));
      }
      feeder.add(arm(30), right: arm(30));
      feeder.add(arm(30), right: arm(30));
      expect(feeder.counter.result.repCount, 0);
      for (var i = 0; i < 4; i++) {
        for (final angle in [90.0, 150.0, 160.0, 90.0, 30.0, 25.0]) {
          feeder.add(arm(angle), right: arm(angle - 5));
        }
      }
      expect(feeder.counter.result.repCount, 4);
      expect(
        const FormChecker().check(jack, feeder.counter.result).issues,
        isEmpty,
      );
    });

    test('min follows the moving (bent) leg in a lunge', () {
      final config = exerciseConfig('reverse-lunge');
      Map<PoseJoint, Point> leg(double angle) => triplet(config.joints, angle);
      final feeder = FrameFeeder(config);
      final first = feeder.add(leg(170), right: leg(90));
      expect(first.currentAngle, closeTo(90, 1e-9));
      expect(first.selectedSide, BodySide.right);
      feeder.add(leg(170), right: leg(172));
      feeder.add(leg(175), right: leg(172));
      // 100° (first <115) to 165° (first >160) is exactly minRepMs 800.
      for (final angle in [130.0, 100.0, 95.0, 90.0, 120.0, 165.0, 170.0]) {
        feeder.add(leg(angle), right: leg(175), stepMs: 200);
      }
      expect(feeder.counter.result.repCount, 1);
      expect(feeder.counter.result.selectedSide, BodySide.left);
    });

    test('max picks the larger angle; auto picks higher confidence', () {
      final json = {
        'joints': ['hip', 'knee', 'ankle'],
        'downBelow': 95,
        'upAbove': 160,
        'minConfidence': 0.5,
        'minRepMs': 0,
      };
      final max = FrameFeeder(CvConfig.fromJson({...json, 'side': 'max'}));
      final maxResult = max.add(
        triplet(max.counter.config.joints, 100),
        right: triplet(max.counter.config.joints, 150),
      );
      expect(maxResult.currentAngle, closeTo(150, 1e-9));
      expect(maxResult.selectedSide, BodySide.right);

      final auto = FrameFeeder(CvConfig.fromJson(json));
      final autoResult = auto.add(
        triplet(auto.counter.config.joints, 100),
        right: triplet(auto.counter.config.joints, 150),
        leftConfidence: 0.95,
        rightConfidence: 0.7,
      );
      expect(autoResult.currentAngle, closeTo(100, 1e-9));
      expect(autoResult.selectedSide, BodySide.left);
    });
  });

  group('push-up: orientation and body-line band rule', () {
    final config = exerciseConfig('push-up');

    void pushUps(
      FrameFeeder feeder, {
      double body = 178,
      bool upright = false,
    }) {
      for (final elbow in [130.0, 100.0, 85.0, 120.0, 160.0, 170.0]) {
        feeder.add(
          pushUpPose(elbow, body: body, upright: upright),
          stepMs: 200,
        );
      }
    }

    test('counts horizontal push-ups with a straight body', () {
      final feeder = FrameFeeder(config);
      feeder.add(pushUpPose(170));
      feeder.add(pushUpPose(170));
      for (var i = 0; i < 3; i++) {
        pushUps(feeder);
      }
      final result = feeder.counter.result;
      expect(result.repCount, 3);
      expect(result.orientationOk, isTrue);
      expect(const FormChecker().check(config, result).issues, isEmpty);
    });

    test('standing upright bending the arms is not a push-up', () {
      final feeder = FrameFeeder(config);
      feeder.add(pushUpPose(170, upright: true));
      feeder.add(pushUpPose(170, upright: true));
      for (var i = 0; i < 3; i++) {
        pushUps(feeder, upright: true);
      }
      final result = feeder.counter.result;
      expect(result.repCount, 0);
      expect(result.orientationOk, isFalse);
      expect(result.personMissing, isFalse);
    });

    test('sagging hips raise body_not_straight by degrees outside band', () {
      final feeder = FrameFeeder(config);
      feeder.add(pushUpPose(170));
      feeder.add(pushUpPose(170));
      pushUps(feeder, body: 155); // 5° under the 160° band → severity 1
      pushUps(feeder, body: 145); // 15° → severity 2
      pushUps(feeder, body: 130); // 30° → severity 3
      final result = feeder.counter.result;
      expect(result.repCount, 3);
      expect(
        result.reps.first.angleRanges['shoulder-hip-ankle']!.min,
        closeTo(155, 1e-9),
      );
      final form = const FormChecker().check(config, result);
      expect(form.issues.map((issue) => issue.toJson()), [
        {'repIndex': 1, 'code': 'body_not_straight', 'severity': 1},
        {'repIndex': 2, 'code': 'body_not_straight', 'severity': 2},
        {'repIndex': 3, 'code': 'body_not_straight', 'severity': 3},
      ]);
      expect(form.formScore, 80);
    });
  });

  group('hold mode', () {
    test('wall sit accumulates time only inside the hold band', () {
      final feeder = FrameFeeder(exerciseConfig('wall-sit'));
      RepCounterResult result = feeder.angle(90);
      expect(result.holdDuration, Duration.zero);
      for (var i = 0; i < 30; i++) {
        result = feeder.angle(90);
      }
      expect(result.holdDuration, const Duration(seconds: 3));
      expect(result.holding, isTrue);
      expect(result.repCount, 0);

      // Standing up (150° > holdMax 120°) stops the clock.
      for (var i = 0; i < 5; i++) {
        result = feeder.angle(150);
      }
      expect(result.holding, isFalse);
      expect(result.holdDuration, const Duration(seconds: 3));

      // The first frame back in band only restarts the clock.
      result = feeder.angle(90);
      expect(result.holdDuration, const Duration(seconds: 3));
      result = feeder.angle(90);
      expect(result.holdDuration, const Duration(milliseconds: 3100));
    });

    test('gaps longer than holdMaxGap are not counted', () {
      final feeder = FrameFeeder(exerciseConfig('wall-sit'));
      feeder.angle(90, stepMs: 600);
      final result = feeder.angle(90);
      expect(result.holdDuration, Duration.zero);
      expect(feeder.angle(90).holdDuration, const Duration(milliseconds: 100));
    });

    test('losing the person stops the clock until frames resume', () {
      final feeder = FrameFeeder(exerciseConfig('wall-sit'));
      for (var i = 0; i < 11; i++) {
        feeder.angle(90);
      }
      expect(feeder.counter.result.holdDuration, const Duration(seconds: 1));
      final missing = feeder.counter.checkPresence(
        Duration(milliseconds: feeder.nextMs + 1100),
      );
      expect(missing.personMissing, isTrue);
      expect(missing.holding, isFalse);
      expect(missing.holdDuration, const Duration(seconds: 1));
      feeder.nextMs += 1200;
      expect(feeder.angle(90).holdDuration, const Duration(seconds: 1));
      final back = feeder.angle(90);
      expect(back.personMissing, isFalse);
      expect(back.holding, isTrue);
      expect(back.holdDuration, const Duration(milliseconds: 1100));
    });

    test('pause (discardIncompleteRep) keeps time and stops the clock', () {
      final feeder = FrameFeeder(exerciseConfig('wall-sit'));
      for (var i = 0; i < 6; i++) {
        feeder.angle(90);
      }
      final paused = feeder.counter.discardIncompleteRep();
      expect(paused.holdDuration, const Duration(milliseconds: 500));
      expect(paused.holding, isFalse);
      expect(feeder.angle(90).holdDuration, const Duration(milliseconds: 500));
      expect(feeder.angle(90).holdDuration, const Duration(milliseconds: 600));
    });

    test('band rule in hold uses the fraction of time outside its band', () {
      final config = exerciseConfig('wall-sit');
      final feeder = FrameFeeder(config);
      feeder.angles(List.filled(31, 90)); // 3.0 s inside 80–100
      feeder.angles(List.filled(10, 110)); // 1.0 s held but outside
      final result = feeder.counter.result;
      expect(result.holdDuration, const Duration(seconds: 4));
      expect(result.holdOutsideByRule.single, const Duration(seconds: 1));
      final form = const FormChecker().check(config, result);
      expect(form.issues.map((issue) => issue.toJson()), [
        {'repIndex': 1, 'code': 'knee_not_at_90', 'severity': 1},
      ]);
      expect(form.formScore, 90);
    });

    test('a short deviation under minFraction is not an issue', () {
      final config = exerciseConfig('wall-sit');
      final feeder = FrameFeeder(config);
      feeder.angles(List.filled(39, 90));
      feeder.angles(List.filled(2, 110)); // 0.2 s of 4 s = 5%
      final form = const FormChecker().check(config, feeder.counter.result);
      expect(form.issues, isEmpty);
      expect(form.formScore, 100);
    });

    test('no hold time yet means score 100 and no issues', () {
      final config = exerciseConfig('wall-sit');
      final form = const FormChecker().check(
        config,
        RepCounter(config: config).result,
      );
      expect(form.issues, isEmpty);
      expect(form.formScore, 100);
    });

    test('plank: lying straight counts, standing upright does not', () {
      final config = exerciseConfig('plank');
      final lying = FrameFeeder(config);
      for (var i = 0; i < 21; i++) {
        lying.add(bodyLine(175));
      }
      expect(lying.counter.result.holdDuration, const Duration(seconds: 2));
      expect(lying.counter.result.orientationOk, isTrue);
      expect(
        const FormChecker().check(config, lying.counter.result).issues,
        isEmpty,
      );

      final standing = FrameFeeder(config);
      for (var i = 0; i < 21; i++) {
        standing.add(bodyLine(175, upright: true));
      }
      expect(standing.counter.result.holdDuration, Duration.zero);
      expect(standing.counter.result.orientationOk, isFalse);
      expect(standing.counter.result.holding, isFalse);
      expect(standing.counter.result.personMissing, isFalse);
    });

    test('plank with sagging hips the whole time is severity 3', () {
      final config = exerciseConfig('plank');
      final feeder = FrameFeeder(config);
      for (var i = 0; i < 21; i++) {
        feeder.add(bodyLine(155)); // inside hold 150–180, outside 165–180
      }
      final form = const FormChecker().check(config, feeder.counter.result);
      expect(form.issues.map((issue) => issue.toJson()), [
        {'repIndex': 1, 'code': 'body_not_straight', 'severity': 3},
      ]);
      expect(form.formScore, 70);
    });
  });
}
