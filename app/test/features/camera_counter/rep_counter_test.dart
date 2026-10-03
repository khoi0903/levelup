import 'package:fitness_app/features/camera_counter/domain/pose.dart';
import 'package:fitness_app/features/camera_counter/domain/rep_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_pose.dart';

void main() {
  test('10 complete squats count exactly 10 with depth and confidence', () {
    final session = SyntheticSession()..arm();
    for (var i = 0; i < 10; i++) {
      session.squat();
    }
    final result = session.counter.result;
    expect(result.repCount, 10);
    expect(result.averageConfidence, closeTo(0.9, 1e-12));
    expect(result.personMissing, isFalse);
    expect(result.state, RepState.up);
    for (var i = 0; i < result.reps.length; i++) {
      final rep = result.reps[i];
      expect(rep.repIndex, i + 1);
      expect(rep.deepestAngle, closeTo(80, 1e-10));
      expect(rep.duration, const Duration(milliseconds: 600));
      expect(rep.averageConfidence, closeTo(0.9, 1e-12));
    }
  });

  test('threshold jitter cannot cause extra state transitions or reps', () {
    final session = SyntheticSession()..arm();
    for (var i = 0; i < 20; i++) {
      session.feed(94);
      session.feed(96);
    }
    expect(session.counter.result.state, RepState.up);
    expect(session.counter.result.repCount, 0);

    session.feed(90);
    session.feed(85);
    for (var i = 0; i < 20; i++) {
      session.feed(161);
      session.feed(159);
    }
    expect(session.counter.result.state, RepState.down);
    expect(session.counter.result.repCount, 0);
    session.feed(170);
    session.feed(175);
    expect(session.counter.result.repCount, 1);
    session.squat();
    expect(session.counter.result.repCount, 2);
  });

  test('interleaved low confidence cannot change count, depth or average', () {
    final session = SyntheticSession()..arm();
    for (var i = 0; i < 10; i++) {
      session.squat(insertLowConfidence: true);
    }
    expect(session.counter.result.repCount, 10);
    expect(session.counter.result.averageConfidence, closeTo(0.9, 1e-12));
    expect(session.counter.result.personMissing, isFalse);
    for (final rep in session.counter.result.reps) {
      expect(rep.deepestAngle, closeTo(80, 1e-10));
    }
  });

  test('an ignored frame interrupts consecutive threshold confirmations', () {
    final session = SyntheticSession()..arm();
    session.feed(90);
    session.feed(20, leftConfidence: 0.2, rightConfidence: 0.2);
    session.feed(85);
    expect(session.counter.result.state, RepState.up);
    session.feed(80);
    expect(session.counter.result.state, RepState.down);
    session.feed(140, stepMs: 400);
    session.feed(170);
    session.feed(175, leftConfidence: 0.2, rightConfidence: 0.2);
    session.feed(170);
    expect(session.counter.result.repCount, 0);
    session.feed(175);
    expect(session.counter.result.repCount, 1);
  });

  test('599 ms is rejected while exactly 600 ms is accepted', () {
    for (final durationMs in [599, 600]) {
      final counter = RepCounter(config: squatConfig());
      counter.addFrame(poseAt(0));
      counter.addFrame(poseAt(100));
      counter.addFrame(poseAt(200, leftAngle: 90, rightAngle: 90));
      counter.addFrame(poseAt(300, leftAngle: 80, rightAngle: 80));
      counter.addFrame(poseAt(200 + durationMs));
      counter.addFrame(poseAt(300 + durationMs));
      expect(counter.result.repCount, durationMs == 600 ? 1 : 0);
      expect(counter.result.state, RepState.up);
    }
  });

  test('a rejected fast rep does not contaminate the next accepted rep', () {
    final session = SyntheticSession()..arm();
    for (final angle in [90.0, 20.0, 170.0, 175.0]) {
      session.feed(angle);
    }
    expect(session.counter.result.repCount, 0);
    session.squat();
    expect(session.counter.result.repCount, 1);
    expect(session.counter.result.reps.single.deepestAngle, closeTo(80, 1e-10));
  });

  test('chooses the more confident side on every frame', () {
    final counter = RepCounter(config: squatConfig());
    for (final time in [0, 100]) {
      final result = counter.addFrame(
        poseAt(time, leftAngle: 80, leftConfidence: 0.7, rightConfidence: 0.95),
      );
      expect(result.selectedSide, BodySide.right);
    }
    for (final time in [200, 300]) {
      final result = counter.addFrame(
        poseAt(time, leftAngle: 80, leftConfidence: 0.95, rightConfidence: 0.7),
      );
      expect(result.selectedSide, BodySide.left);
    }
    counter.addFrame(poseAt(800, leftConfidence: 0.7, rightConfidence: 0.95));
    counter.addFrame(poseAt(900, leftConfidence: 0.95, rightConfidence: 0.7));
    expect(counter.result.repCount, 1);
    expect(counter.result.averageConfidence, closeTo(0.95, 1e-12));
  });

  test('requires every joint to qualify, using the other side if possible', () {
    final counter = RepCounter(config: squatConfig());
    final points = sideLandmarks(BodySide.left, 80, 1);
    points[2] = const PoseLandmark(
      type: PoseLandmarkType.leftKnee,
      x: 0,
      y: 0,
      likelihood: 0.59,
    );
    final result = counter.addFrame(
      PoseFrame(
        timestamp: Duration.zero,
        landmarks: [...points, ...sideLandmarks(BodySide.right, 170, 0.6)],
      ),
    );
    expect(result.selectedSide, BodySide.right);
    expect(result.averageConfidence, closeTo(0.6, 1e-12));
  });

  test(
    'missing joints, invalid likelihood and degenerate geometry are ignored',
    () {
      final counter = RepCounter(config: squatConfig());
      var timeMs = 0;
      final empty = counter.addFrame(
        PoseFrame(
          timestamp: Duration(milliseconds: timeMs++),
          landmarks: [],
        ),
      );
      expect(empty.averageConfidence, 0);
      for (final confidence in [double.nan, double.infinity, -0.1, 1.1]) {
        final result = counter.addFrame(
          poseAt(
            timeMs++,
            leftConfidence: confidence,
            rightConfidence: confidence,
          ),
        );
        expect(result.currentAngle, isNull);
        expect(result.selectedSide, isNull);
        expect(result.averageConfidence, 0);
      }
      final degenerate = sideLandmarks(BodySide.left, 170, 0.9);
      degenerate[1] = const PoseLandmark(
        type: PoseLandmarkType.leftHip,
        x: 0,
        y: 0,
        likelihood: 0.9,
      );
      expect(
        counter
            .addFrame(
              PoseFrame(
                timestamp: Duration(milliseconds: timeMs),
                landmarks: degenerate,
              ),
            )
            .currentAngle,
        isNull,
      );
    },
  );

  test('starting crouched cannot count an incomplete initial rep', () {
    final session = SyntheticSession();
    session.feed(80);
    session.feed(85);
    session.feed(140);
    session.feed(170);
    session.feed(175);
    expect(session.counter.result.repCount, 0);
    session.squat();
    expect(session.counter.result.repCount, 1);
  });

  test('snapshot rep lists are immutable and independent of later frames', () {
    final session = SyntheticSession()..arm();
    session.squat();
    final before = session.counter.result;
    session.squat();
    expect(before.repCount, 1);
    expect(session.counter.result.repCount, 2);
    expect(() => before.reps.clear(), throwsUnsupportedError);
  });

  test('timestamps cannot go backwards or reuse a frame timestamp', () {
    final counter = RepCounter(config: squatConfig());
    counter.addFrame(poseAt(100));
    expect(() => counter.addFrame(poseAt(100)), throwsArgumentError);
    expect(() => counter.addFrame(poseAt(90)), throwsArgumentError);
    counter.checkPresence(const Duration(milliseconds: 200));
    expect(() => counter.addFrame(poseAt(150)), throwsArgumentError);
    expect(
      () => counter.checkPresence(const Duration(milliseconds: 199)),
      throwsArgumentError,
    );
    // A frame may arrive at the same timestamp as the latest timer check.
    expect(counter.addFrame(poseAt(200)).personMissing, isFalse);
  });

  group('person missing', () {
    test('reports absence after >1 second even without frames', () {
      final counter = RepCounter(config: squatConfig());
      expect(
        counter.checkPresence(const Duration(seconds: 1)).personMissing,
        isFalse,
      );
      expect(
        counter.checkPresence(const Duration(milliseconds: 1001)).personMissing,
        isTrue,
      );
      expect(counter.addFrame(poseAt(1100)).personMissing, isFalse);
    });

    test('low-confidence frames do not refresh the last reliable time', () {
      final counter = RepCounter(config: squatConfig());
      counter.addFrame(poseAt(0));
      counter.addFrame(poseAt(100));
      for (final time in [500, 1100, 1101]) {
        final result = counter.addFrame(
          poseAt(time, leftConfidence: 0.2, rightConfidence: 0.2),
        );
        expect(result.personMissing, time > 1100);
      }
    });

    test('cancels an incomplete rep and requires up frames after recovery', () {
      final session = SyntheticSession()..arm();
      session.squat();
      session.feed(90);
      session.feed(80);
      final lastGoodMs = session.nextMs - 100;
      expect(session.counter.result.state, RepState.down);
      expect(
        session.counter
            .checkPresence(Duration(milliseconds: lastGoodMs + 1001))
            .personMissing,
        isTrue,
      );
      session.nextMs = lastGoodMs + 1100;
      session.feed(80);
      session.feed(85);
      session.arm();
      expect(session.counter.result.repCount, 1);
      session.squat();
      expect(session.counter.result.repCount, 2);
    });

    test(
      'detects gaps even if no timer check ran before the next good frame',
      () {
        final counter = RepCounter(config: squatConfig());
        counter.addFrame(poseAt(0));
        counter.addFrame(poseAt(100));
        counter.addFrame(poseAt(200, leftAngle: 90, rightAngle: 90));
        counter.addFrame(poseAt(300, leftAngle: 80, rightAngle: 80));
        counter.addFrame(poseAt(1500));
        counter.addFrame(poseAt(1600));
        expect(counter.result.repCount, 0);
        expect(counter.result.personMissing, isFalse);
      },
    );
  });
}
