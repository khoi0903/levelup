import 'dart:io';
import 'dart:ui' as ui;

import 'package:fitness_app/core/constants/app_colors.dart';
import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:fitness_app/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:fitness_app/features/progress/data/repositories/fake_progress_repository.dart';
import 'package:fitness_app/features/progress/domain/models/progress_models.dart';
import 'package:fitness_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:fitness_app/features/progress/presentation/screens/measurement_screen.dart';
import 'package:fitness_app/features/progress/presentation/screens/progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const output = String.fromEnvironment('FEATURE_PREVIEW_DIR');
  const fontPath = String.fromEnvironment('PREVIEW_FONT_PATH');
  final nutrition = FakeNutritionRepository();
  final screens = <String, Widget>{
    'nutrition': const NutritionScreen(),
    'meal-editor': MealEditorScreen(initialFoods: nutrition.foods),
    'progress': const ProgressScreen(),
    'measurement': const MeasurementScreen(),
  };
  for (final entry in screens.entries) {
    testWidgets('${entry.key} renders at phone width with enlarged text', (
      tester,
    ) async {
      if (fontPath.isNotEmpty) {
        await tester.runAsync(() async {
          final font = FontLoader('Roboto')
            ..addFont(
              File(fontPath)
                  .readAsBytes()
                  .then((bytes) => ByteData.sublistView(bytes)),
            );
          await font.load();
          final iconFont = FontLoader('MaterialIcons')
            ..addFont(
              File('${File(fontPath).parent.path}/MaterialIcons-Regular.otf')
                  .readAsBytes()
                  .then((bytes) => ByteData.sublistView(bytes)),
            );
          await iconFont.load();
        });
      }
      tester.view.physicalSize = const Size(390, 960);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundaryKey = GlobalKey();
      final repo = FakeProgressRepository(
        current: const MeasurementHistory(
          items: [
            Measurement(measuredOn: '2026-08-01', weightKg: 70, waistCm: 88),
            Measurement(measuredOn: '2026-09-01', weightKg: 69, waistCm: 86),
            Measurement(measuredOn: '2026-10-04', weightKg: 68.5, waistCm: 85),
          ],
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nutritionRepositoryProvider.overrideWithValue(nutrition),
            progressRepositoryProvider.overrideWithValue(repo),
          ],
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: AppColors.primary,
                  surface: AppColors.surface,
                ),
                textTheme: ThemeData().textTheme.apply(
                  bodyColor: AppColors.textPrimary,
                  displayColor: AppColors.textPrimary,
                ),
              ),
              home: entry.value,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.3)),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (output.isNotEmpty) {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$output/${entry.key}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      // Small phone: preserve scroll access with larger text, without overflows.
      tester.view.physicalSize = const Size(320, 800);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
