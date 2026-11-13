import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/nutrition/data/photo/meal_photo.dart';
import 'package:fitness_app/features/nutrition/data/repositories/fake_nutrition_repository.dart';
import 'package:fitness_app/features/nutrition/data/speech/meal_speech.dart';
import 'package:fitness_app/features/nutrition/domain/models/nutrition_models.dart';
import 'package:fitness_app/features/nutrition/presentation/controllers/nutrition_controller.dart';
import 'package:fitness_app/features/nutrition/presentation/screens/meal_editor_screen.dart';
import 'package:fitness_app/features/nutrition/presentation/widgets/food_detail_sheet.dart';
import 'package:fitness_app/features/nutrition/presentation/widgets/meal_quick_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoPicker implements MealPhotoPicker {
  @override
  Future<MealPhoto?> pick(MealPhotoSource source) async => null;
}

class FakeMealSpeech implements MealSpeech {
  FakeMealSpeech({this.available = true, this.heard = ''});
  final bool available;
  final String heard;
  int starts = 0;
  @override
  Future<bool> start({
    required void Function(String text) onText,
    required VoidCallback onDone,
  }) async {
    starts++;
    if (!available) return false;
    onText(heard);
    onDone();
    return true;
  }

  @override
  Future<void> stop() async {}
}

const pho = Food(
  foodId: '0000000000000000000000aa',
  nameVi: 'Phở bò',
  servingDesc: '1 tô',
  servingGrams: 550,
  macros: Macros(kcal: 450, proteinG: 25, carbsG: 60, fatG: 12),
);

Future<void> pumpApp(
  WidgetTester tester,
  FakeNutritionRepository repo, {
  String route = '/nutrition',
  Widget? screen,
  MealSpeech? speech,
}) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = createAppRouter(initialLocation: route);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        nutritionRepositoryProvider.overrideWithValue(repo),
        mealPhotoPickerProvider.overrideWithValue(_NoPicker()),
        mealSpeechProvider.overrideWithValue(speech ?? FakeMealSpeech()),
      ],
      child: screen == null
          ? MaterialApp.router(routerConfig: router)
          : MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test('portionLabel đổi khẩu phần sang đơn vị quen dùng', () {
    expect(portionLabel('1 tô', 550, 0.5), '½ tô (275 g)');
    expect(portionLabel('1 tô', 550, 1), '1 tô (550 g)');
    expect(portionLabel('1 tô', 550, 1.5), '1½ tô (825 g)');
    expect(portionLabel('', 100, 2), '2 phần (200 g)');
    expect(portionLabel('100 g', 100, 2), '2 × 100 g (200 g)');
  });

  test('macroShares chia theo năng lượng 4/4/9 và tổng bằng 1', () {
    final s = macroShares(const Macros(proteinG: 10, carbsG: 10, fatG: 10));
    expect(s.protein, closeTo(40 / 170, 1e-9));
    expect(s.fat, closeTo(90 / 170, 1e-9));
    expect(s.protein + s.carbs + s.fat, closeTo(1, 1e-9));
    expect(macroShares(const Macros()).carbs, 0);
  });

  test('Recognition đọc được phản hồi /meals/parse', () {
    final r = Recognition.fromJson({
      'recognitionId': 'abc',
      'items': [
        {
          'name': 'pho bo',
          'nameVi': 'Phở bò',
          'matched': true,
          'foodId': '0000000000000000000000aa',
          'portionGrams': 550,
          'kcal': 450,
          'proteinG': 25,
          'carbsG': 60,
          'fatG': 12,
          'servingDesc': '1 tô',
          'servingGrams': 550,
        },
      ],
    });
    expect(r.cached, isFalse);
    expect(r.items.single.servingGrams, 550);
    expect(r.items.single.valid, isTrue);
  });

  testWidgets('ghi món bằng câu: gửi câu, mở màn sửa bữa rồi lưu như bữa ảnh', (
    tester,
  ) async {
    final repo = FakeNutritionRepository()
      ..parsed = Recognition(
        recognitionId: 'r-text-1',
        items: [MealItem.fromFood(pho)],
      );
    await pumpApp(tester, repo);
    expect(find.text('Ghi món bằng câu'), findsOneWidget);
    final input = find.byKey(const ValueKey('meal-text-input'));
    await tester.ensureVisible(input);
    await tester.enterText(input, '1 tô phở bò');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('meal-text-send')));
    expect(repo.parsedText, '1 tô phở bò');
    expect(mealLabels.containsKey(repo.parsedMeal), isTrue);
    expect(find.text('Kiểm tra lại món ăn'), findsOneWidget);
    expect(find.text('Phở bò'), findsOneWidget);
    await tapVisible(tester, find.text('Lưu bữa ăn'));
    expect(repo.savedRequest!.method, 'photo');
    expect(repo.savedRequest!.recognitionId, 'r-text-1');
    expect(repo.savedRequest!.items.single.foodId, pho.foodId);
  });

  testWidgets('micro điền chữ nghe được vào ô nhập', (tester) async {
    final speech = FakeMealSpeech(heard: '1 ly cà phê sữa');
    await pumpApp(tester, FakeNutritionRepository(), speech: speech);
    await tapVisible(tester, find.byKey(const ValueKey('meal-text-mic')));
    expect(speech.starts, 1);
    expect(find.text('1 ly cà phê sữa'), findsOneWidget);
  });

  testWidgets('máy không dùng được micro thì ẩn nút micro', (tester) async {
    await pumpApp(
      tester,
      FakeNutritionRepository(),
      speech: FakeMealSpeech(available: false),
    );
    await tapVisible(tester, find.byKey(const ValueKey('meal-text-mic')));
    expect(find.byKey(const ValueKey('meal-text-mic')), findsNothing);
    expect(find.textContaining('Chưa dùng được micro'), findsOneWidget);
  });

  testWidgets('hết lượt AI (429) hiện lời nhắn, không rời màn', (tester) async {
    final repo = FakeNutritionRepository()
      ..parseError = const ApiException(
        code: 'PHOTO_LIMIT_REACHED',
        statusCode: 429,
      );
    await pumpApp(tester, repo);
    final input = find.byKey(const ValueKey('meal-text-input'));
    await tester.ensureVisible(input);
    await tester.enterText(input, 'phở');
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const ValueKey('meal-text-send')));
    expect(find.textContaining('Đã hết lượt AI ghi món'), findsOneWidget);
    expect(find.text('Ghi món bằng câu'), findsOneWidget);
  });

  testWidgets(
    'món phổ biến theo bữa: chạm một lần thêm món với khẩu phần mặc định',
    (tester) async {
      final repo = FakeNutritionRepository()..popularFoods = const [pho];
      await pumpApp(tester, repo, route: '/nutrition/add?meal=breakfast');
      expect(repo.popularMeal, 'breakfast');
      expect(find.text('Món phổ biến bữa sáng'), findsOneWidget);
      await tapVisible(tester, find.byKey(ValueKey('popular-${pho.foodId}')));
      expect(find.text('450 kcal ước tính'), findsOneWidget);
      await tapVisible(tester, find.text('Lưu bữa ăn'));
      expect(repo.savedRequest!.meal, 'breakfast');
      expect(repo.savedRequest!.method, 'search');
      expect(repo.savedRequest!.items.single.grams, 550);
    },
  );

  testWidgets('chip khẩu phần đổi số gam và kcal ngay', (tester) async {
    final repo = FakeNutritionRepository();
    await pumpApp(
      tester,
      repo,
      screen: const MealEditorScreen(initialFoods: [pho]),
    );
    expect(find.text('1 tô (550 g)'), findsOneWidget);
    await tapVisible(tester, find.text('2 tô (1100 g)'));
    expect(find.text('900 kcal'), findsOneWidget);
    expect(find.text('900 kcal ước tính'), findsOneWidget);
    await tapVisible(tester, find.text('½ tô (275 g)'));
    expect(find.text('225 kcal'), findsOneWidget);
  });

  testWidgets('chạm tên món mở chi tiết: biểu đồ vòng và % mục tiêu ngày', (
    tester,
  ) async {
    await pumpApp(
      tester,
      FakeNutritionRepository(),
      screen: const MealEditorScreen(initialFoods: [pho]),
    );
    await tapVisible(tester, find.byKey(const ValueKey('item-detail-0')));
    expect(find.byKey(const ValueKey('food-detail-donut')), findsOneWidget);
    expect(find.text('% mục tiêu ngày'), findsOneWidget);
    // 450 / 1800 kcal
    expect(find.text('25% • 450/1800 kcal'), findsOneWidget);
  });

  testWidgets('chạm một ly nước ghi 250 ml', (tester) async {
    final repo = FakeNutritionRepository();
    await pumpApp(tester, repo);
    await tapVisible(tester, find.byKey(const ValueKey('water-glass-0')));
    expect(repo.waterCalls, 1);
    expect(find.textContaining('250 ml / 2000 ml'), findsOneWidget);
    expect(find.text('+250 ml'), findsOneWidget);
  });
}
