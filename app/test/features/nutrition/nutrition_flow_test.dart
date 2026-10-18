import 'dart:typed_data';

import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/nutrition/data/photo/meal_photo.dart';
import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/domain/models/nutrition_models.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/nutrition/presentation/screens/food_search_screen.dart';
import 'package:fitness_app/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:fitness_app/features/nutrition/presentation/screens/nutrition_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

class FakePhotoPicker implements MealPhotoPicker {
  MealPhoto? result = MealPhoto(
    img.encodeJpg(img.Image(width: 8, height: 8)),
    'image/jpeg',
  );
  Object? error;
  MealPhotoSource? source;
  @override
  Future<MealPhoto?> pick(MealPhotoSource source) async {
    this.source = source;
    if (error != null) throw error!;
    return result;
  }
}

Future<void> pumpNutrition(
  WidgetTester tester,
  FakeNutritionRepository repo, {
  Widget? screen,
  String route = '/nutrition',
  FakePhotoPicker? picker,
  List<Food>? foods,
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = createAppRouter(initialLocation: route);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nutritionRepositoryProvider.overrideWithValue(repo),
        mealPhotoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
      ],
      child: screen == null
          ? MaterialApp.router(routerConfig: router)
          : MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('today, macros, empty meals and +250 ml refresh', (tester) async {
    final repo = FakeNutritionRepository();
    await pumpNutrition(tester, repo);
    expect(find.text('Mục tiêu 1800 kcal'), findsOneWidget);
    expect(find.text('Còn lại 1800 kcal'), findsOneWidget);
    expect(find.text('Đạm'), findsOneWidget);
    await tapVisible(tester, find.text('+250 ml'));
    expect(repo.waterCalls, 1);
    expect(find.text('Nước • 250 ml / 2000 ml'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('water failure retries without adding locally', (tester) async {
    final repo = FakeNutritionRepository()
      ..waterError = const ApiException(code: 'NETWORK_ERROR');
    await pumpNutrition(tester, repo);
    await tapVisible(tester, find.text('+250 ml'));
    expect(repo.current.waterMl, 0);
    expect(find.textContaining('Không thể kết nối'), findsOneWidget);
    repo.waterError = null;
    await tapVisible(tester, find.text('Thử lại'));
    expect(repo.current.waterMl, 250);
  });
  testWidgets('today error retry', (tester) async {
    final repo = FakeNutritionRepository()
      ..todayError = const ApiException(code: 'NETWORK_ERROR');
    await pumpNutrition(tester, repo);
    repo.todayError = null;
    await tapVisible(tester, find.text('Thử lại'));
    expect(find.text('Mục tiêu 1800 kcal'), findsOneWidget);
  });
  testWidgets('no target and negative remaining are rendered', (tester) async {
    final repo = FakeNutritionRepository(
      initial: const NutritionToday(localDate: '2026-10-04'),
    );
    await pumpNutrition(tester, repo, screen: const NutritionScreen());
    expect(find.text('Chưa có mục tiêu dinh dưỡng'), findsOneWidget);
    await pumpNutrition(
      tester,
      FakeNutritionRepository(
        initial: const NutritionToday(
          localDate: '2026-10-04',
          target: NutritionTarget(macros: Macros(kcal: 1500), waterMl: 2000),
          consumed: Macros(kcal: 1600),
          remaining: Macros(kcal: -100),
        ),
      ),
      screen: const NutritionScreen(),
    );
    expect(find.text('Vượt mục tiêu 100 kcal'), findsOneWidget);
  });
  testWidgets(
    'manual search accepts unaccented input, edits grams and saves meal',
    (tester) async {
      final repo = FakeNutritionRepository();
      await pumpNutrition(tester, repo, route: '/nutrition/add');
      await tapVisible(tester, find.text('+ Thêm món qua tìm kiếm'));
      await tester.enterText(find.byType(TextField), 'com trang');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repo.lastQuery, 'com trang');
      await tapVisible(tester, find.text('Cơm trắng'));
      await tester.enterText(find.byType(TextFormField), '200');
      await tester.pumpAndSettle();
      expect(find.text('260 kcal'), findsOneWidget);
      await tapVisible(tester, find.text('Tối'));
      await tapVisible(tester, find.text('Lưu bữa ăn'));
      expect(repo.savedRequest!.meal, 'dinner');
      expect(repo.savedRequest!.method, 'search');
      expect(repo.savedRequest!.items.single.grams, 200);
      // Về lại màn Dinh dưỡng (tiêu đề + nhãn tab cùng chữ)
      expect(find.text('Dinh dưỡng'), findsWidgets);
    },
  );
  testWidgets('unmatched AI item must be replaced before saving', (
    tester,
  ) async {
    final repo = FakeNutritionRepository()
      ..recognition = const Recognition(
        recognitionId: '000000000000000000000002',
        items: [MealItem(name: 'Món lạ', grams: 100, baseGrams: 100)],
      );
    await pumpNutrition(tester, repo, route: '/nutrition/photo');
    await tapVisible(tester, find.text('Chọn ảnh từ thư viện'));
    expect(find.textContaining('Món chưa khớp'), findsOneWidget);
    await tapVisible(tester, find.text('Lưu bữa ăn'));
    expect(repo.saveCalls, 0);
    await tapVisible(tester, find.text('Tìm món thay thế'));
    await tapVisible(tester, find.text('Cơm trắng'));
    await tapVisible(tester, find.text('Lưu bữa ăn'));
    expect(repo.savedRequest!.method, 'photo');
    expect(repo.savedRequest!.recognitionId, '000000000000000000000002');
  });
  testWidgets('AI-estimated item shows label and saves without foodId', (
    tester,
  ) async {
    final repo = FakeNutritionRepository()
      ..recognition = const Recognition(
        recognitionId: '000000000000000000000002',
        items: [
          MealItem(
            name: 'Trà dâu kem cheese',
            grams: 500,
            baseGrams: 500,
            baseMacros: Macros(kcal: 375, proteinG: 6, carbsG: 60, fatG: 12),
            estimated: true,
          ),
        ],
      );
    await pumpNutrition(tester, repo, route: '/nutrition/photo');
    await tapVisible(tester, find.text('Chọn ảnh từ thư viện'));
    expect(find.textContaining('AI ước tính'), findsOneWidget);
    expect(find.textContaining('Món chưa khớp'), findsNothing);
    expect(find.text('375 kcal ước tính'), findsOneWidget);
    await tapVisible(tester, find.text('Lưu bữa ăn'));
    final saved = repo.savedRequest!.items.single.toJson();
    expect(saved['foodId'], isNull);
    expect(saved.containsKey('kcal'), isFalse);
    expect(saved['portionGrams'], 500);
  });
  testWidgets('503 switches to manual and can save', (tester) async {
    final repo = FakeNutritionRepository()
      ..recognitionError = const ApiException(
        code: 'AI_UNAVAILABLE',
        statusCode: 503,
      );
    await pumpNutrition(tester, repo, route: '/nutrition/photo');
    await tapVisible(tester, find.text('Chụp ảnh'));
    expect(find.text('Thêm món thủ công'), findsOneWidget);
    await tapVisible(tester, find.text('Tìm món thủ công'));
    await tester.enterText(find.byType(TextField), 'com');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Cơm trắng'));
    await tapVisible(tester, find.text('Lưu bữa ăn'));
    expect(repo.savedRequest!.method, 'search');
    expect(repo.savedRequest!.recognitionId, isNull);
  });
  for (final status in [413, 415, 429, 502]) {
    testWidgets('photo error $status offers manual search', (tester) async {
      final repo = FakeNutritionRepository()
        ..recognitionError = ApiException(
          code: 'HTTP_$status',
          statusCode: status,
        );
      await pumpNutrition(tester, repo, route: '/nutrition/photo');
      await tapVisible(tester, find.text('Chụp ảnh'));
      expect(find.text('Tìm món thủ công'), findsOneWidget);
      expect(repo.saveCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('picker cancellation leaves draft intact', (tester) async {
    final repo = FakeNutritionRepository();
    await pumpNutrition(
      tester,
      repo,
      screen: MealEditorScreen(photoMode: true, initialFoods: repo.foods),
      picker: FakePhotoPicker()..result = null,
    );
    await tapVisible(tester, find.text('Chụp ảnh'));
    expect(find.text('Cơm trắng'), findsOneWidget);
    expect(repo.sentPhoto, isNull);
  });
  testWidgets('invalid grams block save and network failure retains draft', (
    tester,
  ) async {
    final repo = FakeNutritionRepository()
      ..saveError = const ApiException(code: 'NETWORK_ERROR');
    await pumpNutrition(
      tester,
      repo,
      screen: MealEditorScreen(initialFoods: repo.foods),
    );
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Lưu bữa ăn'));
    expect(repo.saveCalls, 0);
    await tester.enterText(find.byType(TextFormField), '150');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Lưu bữa ăn'));
    expect(repo.saveCalls, 1);
    expect(find.text('Cơm trắng'), findsOneWidget);
    expect(find.textContaining('Không thể kết nối'), findsOneWidget);
  });
  testWidgets('search empty results and retry', (tester) async {
    final repo = FakeNutritionRepository(foods: [])
      ..searchError = const ApiException(code: 'NETWORK_ERROR');
    await pumpNutrition(
      tester,
      repo,
      screen: const FoodSearchScreen(initialQuery: 'com'),
    );
    repo.searchError = null;
    await tapVisible(tester, find.text('Thử lại'));
    expect(find.textContaining('Chưa tìm thấy món'), findsOneWidget);
  });
  testWidgets('suggestion appears only when returned', (tester) async {
    final food = FakeNutritionRepository().foods.single;
    final repo = FakeNutritionRepository(
      initial: NutritionToday(
        localDate: '2026-10-04',
        suggestion: DinnerSuggestion(message: 'Thêm đạm nhé.', foods: [food]),
      ),
    );
    await pumpNutrition(tester, repo);
    await tapVisible(tester, find.text('Kiểm tra và thêm bữa tối'));
    expect(find.text('Cơm trắng'), findsOneWidget);
    await tapVisible(tester, find.text('Lưu bữa ăn'));
    expect(repo.savedRequest!.meal, 'dinner');
  });
  test('photo limits and media validation', () {
    expect(
      () => MealPhoto(Uint8List(maxMealPhotoBytes + 1), 'image/jpeg'),
      throwsA(isA<ApiException>()),
    );
    expect(
      () => MealPhoto(Uint8List.fromList([1]), 'image/gif'),
      throwsA(isA<ApiException>()),
    );
  });
  testWidgets('non-finite and extreme grams do not crash or save', (
    tester,
  ) async {
    final repo = FakeNutritionRepository();
    await pumpNutrition(
      tester,
      repo,
      screen: MealEditorScreen(initialFoods: repo.foods),
    );
    for (final input in ['NaN', 'Infinity', '1e300', '-10', '3001']) {
      await tester.ensureVisible(find.byType(TextFormField));
      await tester.enterText(find.byType(TextFormField), input);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Lưu bữa ăn'));
      expect(repo.saveCalls, 0);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('photo save retry preserves edited grams and recognition', (
    tester,
  ) async {
    final repo = FakeNutritionRepository()
      ..saveError = const ApiException(code: 'NETWORK_ERROR');
    await pumpNutrition(tester, repo, route: '/nutrition/photo');
    await tapVisible(tester, find.text('Chụp ảnh'));
    await tester.ensureVisible(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '180');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Lưu bữa ăn'));
    expect(find.text('Thử nhận diện lại'), findsNothing);
    repo.saveError = null;
    await tapVisible(tester, find.text('Thử lưu lại'));
    expect(repo.savedRequest!.items.single.grams, 180);
    expect(repo.savedRequest!.recognitionId, isNotNull);
  });
}
