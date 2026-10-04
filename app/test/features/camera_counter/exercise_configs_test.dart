import 'dart:convert';
import 'dart:io';

import 'package:fitness_app/features/camera_counter/domain/camera_counter.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_pose.dart';

void main() {
  group('mongo/cv-configs.json', () {
    final all = cvConfigsJson();

    test('every config of every exercise parses and round trips', () {
      expect(all, isNotEmpty);
      for (final entry in all.entries) {
        final exercise = entry.value as Map<String, dynamic>;
        expect(exercise['activeVersion'], isA<int>(), reason: entry.key);
        expect(
          () => activeCvEntry(exercise),
          returnsNormally,
          reason: '${entry.key}: activeVersion must match one config',
        );
        for (final raw
            in (exercise['configs'] as List).cast<Map<String, dynamic>>()) {
          expect(raw['version'], isA<int>(), reason: entry.key);
          expect(raw['cameraPosition'], isIn(['side', 'front']));
          final config = CvConfig.fromJson(
            raw['config'] as Map<String, dynamic>,
          );
          final again = CvConfig.fromJson(
            jsonDecode(jsonEncode(config.toJson())) as Map<String, dynamic>,
          );
          expect(again.toJson(), config.toJson(), reason: entry.key);
        }
      }
    });

    test('exercises.json cv.supported matches the configured slugs', () {
      final exercises = (jsonDecode(
        File('../mongo/seed/exercises.json').readAsStringSync(),
      ) as List).cast<Map<String, dynamic>>();
      final supported = {
        for (final exercise in exercises)
          if ((exercise['cv'] as Map<String, dynamic>?)?['supported'] == true)
            exercise['slug'] as String,
      };
      expect(supported, all.keys.toSet());
      for (final exercise in exercises) {
        expect(
          exercise['cv'],
          isA<Map<String, dynamic>>(),
          reason: '${exercise['slug']} must declare cv.supported',
        );
      }
    });

    test('new configs carry a Vietnamese setup tip and placement', () {
      for (final slug in all.keys.where((slug) => slug != 'bodyweight-squat')) {
        final config = exerciseConfig(slug);
        expect(config.setupTipVi, isNotEmpty, reason: slug);
        expect(config.placement, isNotEmpty, reason: slug);
      }
    });

    test('plank and wall-sit are hold exercises; the rest count reps', () {
      for (final slug in all.keys) {
        expect(
          exerciseConfig(slug).mode,
          slug == 'plank' || slug == 'wall-sit' ? CvMode.hold : CvMode.reps,
          reason: slug,
        );
      }
    });
  });

  group('legacy squat JSON', () {
    const oldJson = {
      'joints': ['hip', 'knee', 'ankle'],
      'downBelow': 120,
      'upAbove': 160,
      'minConfidence': 0.6,
      'minRepMs': 500, // lets the synthetic 112°/114° squats (500 ms) count
    };

    test('defaults to flex, reps, auto side and shallow_depth rule', () {
      final config = CvConfig.fromJson(oldJson);
      expect(config.direction, CvDirection.flex);
      expect(config.mode, CvMode.reps);
      expect(config.side, CvSide.auto);
      expect(config.orientation, isNull);
      expect(config.formRules.single.toJson(), {
        'type': 'min_depth',
        'code': 'shallow_depth',
        'angle': 100.0,
        'severity': [110.0, 120.0],
      });
      // toJson does not invent the default rule or new fields.
      expect(config.toJson(), oldJson);
    });

    test('counts and grades exactly like before', () {
      final legacyRule = CvConfig.fromJson({
        ...oldJson,
        'formRules': [
          {'code': 'shallow_depth', 'maxDepthAngle': 100},
        ],
      });
      for (final config in [CvConfig.fromJson(oldJson), legacyRule]) {
        final session = SyntheticSession(config: config)..arm();
        for (final depth in [80.0, 105.0, 112.0, 114.0]) {
          session.squat(deepestAngle: depth);
        }
        final result = session.counter.result;
        expect(result.repCount, 4);
        final viaConfig = const FormChecker().check(config, result);
        final viaLegacy = const FormChecker().checkSquats(result.reps);
        final expected = [
          {'repIndex': 2, 'code': 'shallow_depth', 'severity': 1},
          {'repIndex': 3, 'code': 'shallow_depth', 'severity': 2},
          {'repIndex': 4, 'code': 'shallow_depth', 'severity': 2},
        ];
        expect(viaConfig.issues.map((issue) => issue.toJson()), expected);
        expect(viaLegacy.issues.map((issue) => issue.toJson()), expected);
        expect(viaConfig.formScore, viaLegacy.formScore);
        expect(viaConfig.formScore, (100 - 50 / 4).round());
      }
    });

    test('bodyweight-squat seed config equals the old sample config', () {
      final seed = SyntheticSession(config: exerciseConfig('bodyweight-squat'))
        ..arm();
      final sample = SyntheticSession(config: squatConfig())..arm();
      for (final session in [seed, sample]) {
        for (var i = 0; i < 5; i++) {
          session.squat();
        }
      }
      expect(seed.counter.result.repCount, 5);
      expect(
        seed.counter.result.reps.map((rep) => rep.deepestAngle),
        sample.counter.result.reps.map((rep) => rep.deepestAngle),
      );
    });
  });

  group('validation', () {
    const reps = {
      'joints': ['shoulder', 'elbow', 'wrist'],
      'downBelow': 90,
      'upAbove': 150,
      'minConfidence': 0.5,
      'minRepMs': 500,
    };
    const hold = {
      'mode': 'hold',
      'joints': ['hip', 'knee', 'ankle'],
      'holdMin': 70,
      'holdMax': 110,
      'minConfidence': 0.5,
    };

    test('hold config needs no thresholds or minRepMs', () {
      final config = CvConfig.fromJson(hold);
      expect(config.isHold, isTrue);
      expect(config.minRepMs, 0);
      expect(config.holdMin, 70);
      expect(config.holdMax, 110);
      expect(config.formRules, isEmpty);
    });

    test('rejects malformed new fields', () {
      final cases = <Map<String, dynamic>>[
        {...reps, 'direction': 'sideways'},
        {...reps, 'mode': 'timed'},
        {...reps, 'side': 'left'},
        {
          ...reps,
          'joints': ['shoulder', 'elbow', 'pinky'],
        },
        {...reps, 'placement': 3},
        {...reps, 'setupTipVi': false},
        {...reps, 'formRules': 'none'},
        {
          ...reps,
          'formRules': [1],
        },
        {
          ...reps,
          'orientation': {
            'joints': ['shoulder', 'shoulder'],
            'axis': 'horizontal',
          },
        },
        {
          ...reps,
          'orientation': {
            'joints': ['shoulder', 'ankle'],
            'axis': 'diagonal',
          },
        },
        {
          ...reps,
          'orientation': {
            'joints': ['shoulder', 'ankle'],
            'axis': 'horizontal',
            'maxTiltDeg': 90,
          },
        },
        {...hold, 'holdMax': null},
        {...hold, 'holdMin': 120},
        {...hold, 'holdMax': 181},
        {
          ...hold,
          'formRules': [
            {
              'type': 'min_depth',
              'code': 'x',
              'angle': 90,
              'severity': [95, 100],
            },
          ],
        },
        {
          // Hold severity is a time fraction and must stay within 0..1.
          ...hold,
          'formRules': [
            {
              'type': 'band',
              'code': 'x',
              'min': 80,
              'max': 100,
              'severity': [5, 10],
            },
          ],
        },
      ];
      for (final json in cases) {
        expect(
          () => CvConfig.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });

    test('rejects inconsistent form rules', () {
      final cases = <Map<String, dynamic>>[
        {
          'type': 'nope',
          'code': 'x',
          'severity': [1, 2],
        },
        {
          'type': 'band',
          'code': 'Bad-Code',
          'min': 1,
          'max': 2,
          'severity': [1, 2],
        },
        {
          'type': 'min_depth',
          'code': 'x',
          'angle': 90,
          'severity': [85, 100],
        },
        {
          'type': 'min_depth',
          'code': 'x',
          'angle': 90,
          'severity': [100, 95],
        },
        {
          'type': 'min_depth',
          'code': 'x',
          'severity': [95, 100],
        },
        {
          'type': 'max_extreme',
          'code': 'x',
          'angle': 160,
          'severity': [150, 155],
        },
        {
          'type': 'max_extreme',
          'code': 'x',
          'angle': 160,
          'severity': [165, 150],
        },
        {
          'type': 'band',
          'code': 'x',
          'min': 100,
          'max': 90,
          'severity': [1, 2],
        },
        {
          'type': 'band',
          'code': 'x',
          'min': 90,
          'max': 100,
          'severity': [2, 1],
        },
        {
          'type': 'band',
          'code': 'x',
          'min': 90,
          'max': 100,
          'severity': [1, 2],
          'minFraction': 1,
        },
        {
          'type': 'band',
          'code': 'x',
          'joints': ['hip', 'knee'],
          'min': 90,
          'max': 100,
          'severity': [1, 2],
        },
        {
          'type': 'band',
          'code': 'x',
          'min': 90,
          'max': 100,
          'severity': [1],
        },
        {'type': 'band', 'code': 'x', 'min': 90, 'max': 100, 'severity': '1,2'},
      ];
      for (final json in cases) {
        expect(
          () => FormRule.fromJson(json),
          throwsFormatException,
          reason: '$json',
        );
      }
    });

    test('form rules with their own joints are tracked once', () {
      final config = exerciseConfig('push-up');
      expect(config.trackedTriplets.map(tripletKey), [
        'shoulder-elbow-wrist',
        'shoulder-hip-ankle',
      ]);
    });
  });
}
