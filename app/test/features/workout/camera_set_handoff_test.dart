import 'dart:async';

import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/workout/data/camera/rep_counting_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../camera_counter/session_handoff_helpers.dart';
import 'workout_test_helpers.dart';

Future<void> tap(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

String? count(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('camera-rep-count'))).data;

void main() {
  for (final skip in [false, true]) {
    for (final back in [true, false]) {
      testWidgets(
        'set 2 counts after ${back ? 'back' : 'save'}, skip setup today=$skip',
        (tester) async {
          final hardware = SharedCameraHardware();
          final harness = WorkoutHarness(
            plan: planWith([
              const ItemView(
                exerciseId: squatId,
                nameVi: 'Squat',
                sets: 2,
                reps: 10,
              ),
            ]),
            factory: CameraRepSessionFactory(sessionBuilder: hardware.create),
          );
          await harness.pump(tester, '/workout/$sessionId');
          await tap(tester, 'Bắt đầu');
          await tap(tester, 'Đếm bằng camera');
          if (skip) {
            await tester.tap(find.byKey(const ValueKey('camera-skip-today')));
            await tester.pump();
          }
          await tap(tester, 'Tôi đã sẵn sàng');
          await tester.pump(const Duration(seconds: 4));
          await hardware.rep(tester, 0);
          expect(count(tester), '1');

          Completer<void>? release;
          if (back) {
            release = Completer<void>();
            hardware.cameras[0].release = release;
            final navigator = tester.state<NavigatorState>(
              find.byType(Navigator).last,
            );
            await navigator.maybePop();
            await tester.pumpAndSettle();
            // Record set 1 manually after back, then open a new route for set 2.
            await tap(tester, 'Đếm tay: xong hiệp');
          } else {
            await tap(tester, 'Xong hiệp');
            await tap(tester, 'Lưu hiệp');
          }
          await tap(tester, 'Đếm bằng camera');
          if (!skip) {
            expect(find.text('Tôi đã sẵn sàng'), findsOneWidget);
            await tap(tester, 'Tôi đã sẵn sàng');
          } else {
            expect(find.text('Tôi đã sẵn sàng'), findsNothing);
          }
          expect(find.text('Hiệp 2/2'), findsOneWidget);
          expect(count(tester), '0');
          release?.complete();
          await tester.pumpAndSettle();
          await tester.pump(const Duration(seconds: 4));
          await hardware.rep(tester, 1);
          final secondCount = count(tester);
          final secondCalls = hardware.detectors[1].calls;
          if (back) {
            await tap(tester, 'Xong hiệp');
          } else {
            // The active screen uses the saved rep count (1) as set 2's
            // target. It must finish only after that new rep is delivered.
            await tester.pump(const Duration(seconds: 1));
            await tester.pumpAndSettle();
          }
          expect(secondCount, '1');
          expect(secondCalls, greaterThan(0));
          expect(find.text('Camera đếm được 1 lần'), findsOneWidget);
          expect(hardware.detectors.every((d) => d.closed == 1), isTrue);
        },
      );
    }
  }
}
