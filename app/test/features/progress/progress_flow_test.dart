import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/progress/data/repositories/fake_progress_repository.dart';
import 'package:fitness_app/features/progress/domain/models/progress_models.dart';
import 'package:fitness_app/features/progress/presentation/controllers/progress_controller.dart';
import 'package:fitness_app/features/progress/presentation/widgets/measurement_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> pumpProgress(
  WidgetTester tester,
  FakeProgressRepository repo, {
  String route = '/progress',
}) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final router = createAppRouter(initialLocation: route);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [progressRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tapSave(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Lưu số đo'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Lưu số đo'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty progress offers first measurement and fetches 90 days', (
    tester,
  ) async {
    final repo = FakeProgressRepository();
    await pumpProgress(tester, repo);
    expect(repo.requestedDays, 90);
    expect(find.text('Chưa có dữ liệu cân nặng.'), findsOneWidget);
    expect(find.text('Chưa có dữ liệu vòng eo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('save all five fields with decimal comma and show new badge', (
    tester,
  ) async {
    final repo = FakeProgressRepository()
      ..achievements = const [
        ProgressAchievement(
          code: 'waist_down',
          nameVi: 'Vòng eo thay đổi',
          descriptionVi: 'Bạn đã tiến bộ.',
        ),
      ];
    await pumpProgress(tester, repo, route: '/progress/measurements');
    for (final entry in {
      'weightKg': '65,5',
      'waistCm': '80',
      'hipCm': '95',
      'chestCm': '90',
      'armCm': '28',
    }.entries) {
      final finder = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(finder);
      await tester.enterText(finder, entry.value);
    }
    await tapSave(tester);
    expect(repo.savedRequest!.weightKg, 65.5);
    expect(repo.savedRequest!.waistCm, 80);
    expect(repo.savedRequest!.hipCm, 95);
    expect(repo.savedRequest!.chestCm, 90);
    expect(repo.savedRequest!.armCm, 28);
    expect(repo.savedRequest!.toJson().containsKey('measuredOn'), isFalse);
    expect(find.text('65.5 kg'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Huy hiệu mới'), 250);
    expect(find.text('Vòng eo thay đổi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty and out of range input block POST', (tester) async {
    final repo = FakeProgressRepository();
    await pumpProgress(tester, repo, route: '/progress/measurements');
    await tapSave(tester);
    expect(find.text('Nhập ít nhất một chỉ số.'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('weightKg')));
    await tester.enterText(find.byKey(const ValueKey('weightKg')), '19');
    await tapSave(tester);
    expect(find.text('Nhập từ 20 đến 350'), findsOneWidget);
    expect(repo.saveCalls, 0);
  });
  testWidgets('failed save retains values and retries', (tester) async {
    final repo = FakeProgressRepository()
      ..saveError = const ApiException(code: 'NETWORK_ERROR');
    await pumpProgress(tester, repo, route: '/progress/measurements');
    await tester.enterText(find.byKey(const ValueKey('weightKg')), '70');
    await tapSave(tester);
    expect(find.textContaining('Không thể kết nối'), findsOneWidget);
    expect(find.text('70'), findsOneWidget);
    repo.saveError = null;
    await tapSave(tester);
    expect(find.text('70.0 kg'), findsOneWidget);
  });
  testWidgets('history error retry and single point charts', (tester) async {
    final repo = FakeProgressRepository(
      current: const MeasurementHistory(
        items: [
          Measurement(measuredOn: '2026-10-04', weightKg: 70, waistCm: 85),
        ],
      ),
    )..historyError = const ApiException(code: 'NETWORK_ERROR');
    await pumpProgress(tester, repo);
    repo.historyError = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('70.0 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('sparse chart data uses real dates, omits absent values and sorts', () {
    const rows = [
      Measurement(measuredOn: '2026-10-04', waistCm: 82),
      Measurement(measuredOn: '2026-08-01', weightKg: 70),
      Measurement(measuredOn: '2026-09-01', weightKg: 69, waistCm: 85),
    ];
    final weight = measurementPoints(rows, waist: false);
    expect(weight.map((e) => e.value), [70, 69]);
    expect(weight.last.date.difference(weight.first.date).inDays, 31);
    expect(measurementPoints(rows, waist: true).map((e) => e.value), [85, 82]);
  });
  test('fake merges repeated measurements on same local day', () async {
    final repo = FakeProgressRepository();
    await repo.save(const MeasurementRequest(weightKg: 70));
    await repo.save(const MeasurementRequest(waistCm: 85));
    expect(repo.current.items.length, 1);
    expect(repo.current.items.single.weightKg, 70);
    expect(repo.current.items.single.waistCm, 85);
  });
}
