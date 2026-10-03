import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/core/constants/app_colors.dart';
import 'package:fitness_app/features/home/presentation/screens/home_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_body_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_coach_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_goal_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_notify_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_plan_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_schedule_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_start_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_training_screen.dart';
import 'package:fitness_app/features/onboarding/presentation/screens/ob_why_screen.dart';
import 'package:fitness_app/features/workout/presentation/screens/workout_screen.dart';

void main() {
  final screens = <String, Widget>{
    '01_Main': const ObGoalScreen(),
    '02_OB-Body': const ObBodyScreen(),
    '03_OB-Training': const ObTrainingScreen(),
    '04_OB-Schedule': const ObScheduleScreen(),
    '05_OB-Why': const ObWhyScreen(),
    '06_OB-Coach': const ObCoachScreen(),
    '07_OB-Plan': const ObPlanScreen(),
    '08_OB-Notify': const ObNotifyScreen(),
    '09_OB-Start': const ObStartScreen(),
    '10_Home': const HomeScreen(),
    '11_Workout': const WorkoutScreen(),
  };

  testWidgets('Capture screenshots of all 11 screens', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;

    final testTheme = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        error: Colors.redAccent,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
    );

    final dir = Directory('screenshots');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final entry in screens.entries) {
      final key = GlobalKey();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: testTheme,
            debugShowCheckedModeBanner: false,
            home: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 390,
                height: 844,
                child: entry.value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final pngBytes = byteData!.buffer.asUint8List();

        final file = File('screenshots/${entry.key}.png');
        await file.writeAsBytes(pngBytes);
      });
    }
  });
}
