import 'dart:convert';
import 'dart:io';

import 'package:fitness_app/features/camera_counter/domain/camera_counter.dart';
import 'package:fitness_app/features/camera_counter/presentation/debug_counter_screen.dart';
import 'package:fitness_app/features/camera_counter/presentation/debug_exercise_configs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'synthetic_pose.dart';

void main() {
  test('debug copy matches mongo/cv-configs.json and exercise names', () {
    expect(jsonDecode(debugCvConfigsJson), cvConfigsJson());
    final exercises = (jsonDecode(
      File('../mongo/seed/exercises.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>();
    expect(debugExerciseNamesVi, {
      for (final exercise in exercises)
        if ((exercise['cv'] as Map<String, dynamic>)['supported'] == true)
          exercise['slug']: exercise['nameVi'],
    });
    final configs = debugExerciseConfigs();
    expect(configs.map((e) => e.slug), cvConfigsJson().keys);
    for (final exercise in configs) {
      expect(exercise.nameVi, isNot(exercise.slug));
      expect(exercise.config.toJson(), exerciseConfig(exercise.slug).toJson());
    }
  });

  testWidgets('picker switches between rep and hold exercises', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: DebugCounterScreen(autoStart: false)),
    );
    expect(find.byKey(const ValueKey('debug-rep-count')), findsOneWidget);
    expect(find.text('0 lần'), findsOneWidget);
    expect(find.textContaining('Góc hip–knee–ankle'), findsOneWidget);

    // Tall view so the dropdown menu builds every item.
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('debug-exercise-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plank • giữ • side').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('debug-rep-count')), findsNothing);
    expect(find.text('00:00.0'), findsOneWidget);
    expect(find.textContaining('Góc shoulder–hip–ankle'), findsOneWidget);
    final plank = debugExerciseConfigs().firstWhere((e) => e.slug == 'plank');
    expect(find.text(plank.config.setupTipVi!), findsOneWidget);
    expect(
      find.textContaining('Giữ khi góc trong 150.0°–180.0°'),
      findsOneWidget,
    );
  });

  testWidgets('a passed config is listed first', (tester) async {
    final custom = CvConfig.fromJson({
      'joints': ['shoulder', 'elbow', 'wrist'],
      'direction': 'extend',
      'downBelow': 100,
      'upAbove': 150,
      'minConfidence': 0.5,
      'minRepMs': 300,
    });
    await tester.pumpWidget(
      MaterialApp(home: DebugCounterScreen(config: custom, autoStart: false)),
    );
    expect(find.text('Cấu hình truyền vào • đếm • -'), findsOneWidget);
    expect(find.textContaining('Đếm: lên >150.0°'), findsOneWidget);
  });
}
