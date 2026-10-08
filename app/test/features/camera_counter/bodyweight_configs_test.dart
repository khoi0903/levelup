import 'dart:convert';
import 'dart:io';

import 'package:fitness_app/features/camera_counter/domain/camera_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_pose.dart';

const newCameraSlugs = [
  'close-grip-wall-push-up',
  'wall-triceps-extension',
  'standing-hamstring-curl',
];

/// Side view: torso stays upright; elbow flexes toward the wall or the
/// knee flexes behind the standing thigh. The far leg can remain straight.
Map<PoseJoint, Point> sidePose(String slug, double angle, {double body = 178}) {
  if (slug == 'standing-hamstring-curl') {
    const Point hip = (0, -2);
    const Point knee = (0, 0);
    return {
      PoseJoint.shoulder: (0, -4),
      PoseJoint.hip: hip,
      PoseJoint.knee: knee,
      PoseJoint.ankle: bend(hip, knee, angle, length: 2),
    };
  }
  const Point shoulder = (0, 0);
  const Point hip = (0, 2);
  // Triceps extension has hands higher than the close-grip wall push-up.
  final Point elbow = slug == 'wall-triceps-extension' ? (1, -0.5) : (1, 0.5);
  return {
    PoseJoint.shoulder: shoulder,
    PoseJoint.elbow: elbow,
    PoseJoint.wrist: bend(shoulder, elbow, angle),
    PoseJoint.hip: hip,
    PoseJoint.ankle: bend(shoulder, hip, body, length: 2),
  };
}

void feedAngles(
  FrameFeeder feeder,
  String slug,
  Iterable<double> angles, {
  int stepMs = 250,
  double confidence = 0.9,
  double body = 178,
}) {
  for (final angle in angles) {
    feeder.add(
      sidePose(slug, angle, body: body),
      right: slug == 'standing-hamstring-curl' ? sidePose(slug, 175) : {},
      stepMs: stepMs,
      leftConfidence: confidence,
      rightConfidence: confidence,
    );
  }
}

const completeCycle = [135.0, 95.0, 95.0, 95.0, 130.0, 165.0, 170.0];

void main() {
  test('new seed flags expose only the three simple side-view configs', () {
    final seed = (jsonDecode(
      File('../mongo/seed/exercises.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>();
    final added = seed.skip(20).toList();
    expect(added, hasLength(14));
    expect(
      added
          .where((e) => (e['cv'] as Map)['supported'] == true)
          .map((e) => e['slug']),
      unorderedEquals(newCameraSlugs),
    );
    for (final exercise in added) {
      expect(
        cvConfigsJson().containsKey(exercise['slug']),
        (exercise['cv'] as Map)['supported'],
        reason: exercise['slug'] as String,
      );
    }
  });

  for (final slug in newCameraSlugs) {
    group(slug, () {
      test('three controlled full cycles count and grade good form', () {
        final config = exerciseConfig(slug);
        final feeder = FrameFeeder(config);
        feedAngles(feeder, slug, [165, 170]);
        for (var i = 0; i < 3; i++) {
          feedAngles(feeder, slug, completeCycle);
        }
        expect(feeder.counter.result.repCount, 3);
        final form = const FormChecker().check(config, feeder.counter.result);
        expect(form.issues, isEmpty);
        expect(form.formScore, 100);
        expect(config.placement, 'table_side');
      });

      test(
        'starting bent, partial range and one-frame jitter do not count',
        () {
          final feeder = FrameFeeder(exerciseConfig(slug));
          feedAngles(feeder, slug, [95, 95, 165, 170]);
          feedAngles(feeder, slug, [130, 125, 130, 165, 170]);
          feedAngles(feeder, slug, [95, 165, 170, 95, 165, 170]);
          expect(feeder.counter.result.repCount, 0);
          feedAngles(feeder, slug, completeCycle);
          expect(feeder.counter.result.repCount, 1);
        },
      );

      test('fast cycles and low-confidence motion do not count', () {
        final feeder = FrameFeeder(exerciseConfig(slug));
        feedAngles(feeder, slug, [165, 170]);
        feedAngles(feeder, slug, completeCycle, stepMs: 50);
        expect(feeder.counter.result.repCount, 0);
        feedAngles(feeder, slug, completeCycle, confidence: 0.3);
        expect(feeder.counter.result.repCount, 0);
        feedAngles(feeder, slug, [165, 170]);
        feedAngles(feeder, slug, completeCycle);
        expect(feeder.counter.result.repCount, 1);
      });

      test('counted shallow cycles emit the matching spoken issue code', () {
        final config = exerciseConfig(slug);
        final feeder = FrameFeeder(config);
        feedAngles(feeder, slug, [165, 170]);
        feedAngles(feeder, slug, [135, 112, 112, 112, 130, 165, 170]);
        expect(feeder.counter.result.repCount, 1);
        final form = const FormChecker().check(config, feeder.counter.result);
        final depthCode = switch (slug) {
          'close-grip-wall-push-up' => 'pushup_not_deep_enough',
          'wall-triceps-extension' => 'triceps_not_bent_enough',
          _ => 'hamstring_not_curled_enough',
        };
        expect(form.issues.map((issue) => issue.code), [depthCode]);
        expect(form.issues.single.severity, 3);
        final cues = jsonDecode(
          File('assets/content/form-cues.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        expect(cues['exercises'][slug]['issues'][depthCode], isNotNull);
      });

      if (slug != 'standing-hamstring-curl') {
        test(
          'bent body emits the body-line cue independently of elbow depth',
          () {
            final config = exerciseConfig(slug);
            final feeder = FrameFeeder(config);
            feedAngles(feeder, slug, [165, 170], body: 145);
            feedAngles(feeder, slug, completeCycle, body: 145);
            expect(feeder.counter.result.repCount, 1);
            final form = const FormChecker().check(
              config,
              feeder.counter.result,
            );
            expect(form.issues.map((issue) => issue.code), [
              'body_not_straight',
            ]);
          },
        );
      } else {
        test('a confident resting leg cannot hide the moving leg', () {
          final feeder = FrameFeeder(exerciseConfig(slug));
          for (final angle in [165.0, 170.0, ...completeCycle]) {
            feeder.add(
              sidePose(slug, 175),
              right: sidePose(slug, angle),
              stepMs: 250,
              leftConfidence: 0.95,
              rightConfidence: 0.7,
            );
          }
          expect(feeder.counter.result.repCount, 1);
        });
      }
    });
  }
}
