import 'package:fitness_app/features/activity/data/repositories/api_activity_repository.dart';
import 'package:fitness_app/features/activity/data/repositories/fake_activity_repository.dart';
import 'package:fitness_app/features/activity/domain/models/activity_models.dart';
import 'package:fitness_app/features/activity/presentation/screens/activity_history_screen.dart';
import 'package:fitness_app/features/health_connect/data/services/health_connect_service.dart';
import 'package:fitness_app/features/health_connect/presentation/controllers/health_connect_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'activity_mobility_test.dart' show FakeHealthConnectService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('activeKcalInWindows', () {
    final w = WorkoutWindow(
      startedAt: DateTime.utc(2026, 10, 19, 10),
      endedAt: DateTime.utc(2026, 10, 19, 10, 30),
    );
    test('chia theo tỉ lệ thời gian trùng giờ tập', () {
      final kcal = activeKcalInWindows([
        // 10:00–10:20 nằm trọn trong buổi tập
        (
          from: DateTime.utc(2026, 10, 19, 10),
          to: DateTime.utc(2026, 10, 19, 10, 20),
          kcal: 60,
        ),
        // 10:20–10:40 trùng một nửa
        (
          from: DateTime.utc(2026, 10, 19, 10, 20),
          to: DateTime.utc(2026, 10, 19, 10, 40),
          kcal: 40,
        ),
        // Đi bộ buổi chiều: không trùng
        (
          from: DateTime.utc(2026, 10, 19, 15),
          to: DateTime.utc(2026, 10, 19, 16),
          kcal: 100,
        ),
      ], [w]);
      expect(kcal, 80);
    });
    test('không có buổi tập thì 0', () {
      expect(
        activeKcalInWindows([
          (
            from: DateTime.utc(2026, 10, 19, 10),
            to: DateTime.utc(2026, 10, 19, 11),
            kcal: 50,
          ),
        ], const []),
        0,
      );
    });
  });

  test('đồng bộ: lấy số máy chủ, gửi phần calo trùng giờ tập, hiện số lớn hơn', () async {
    final service = FakeHealthConnectService()
      ..steps = 1200
      ..calories = 180
      ..kcalInWorkouts = 40.4;
    final repo = FakeActivityRepository()
      ..today = ActivityToday(
        localDate: '2026-10-19',
        steps: 5200, // máy khác của cùng tài khoản đã gửi nhiều hơn
        activeKcal: 150,
        workoutWindows: [
          WorkoutWindow(
            startedAt: DateTime.utc(2026, 10, 19, 3),
            endedAt: DateTime.utc(2026, 10, 19, 3, 30),
          ),
        ],
      );
    final controller = HealthConnectController(
      service,
      activityRepository: repo,
      clock: () => DateTime(2026, 10, 19, 18),
      isPlatformSupportedOverride: () => true,
    );
    await pumpEventQueue();
    expect(repo.todayCalls, 1);
    expect(service.lastWindows, hasLength(1));
    expect(repo.sentRequests.single.activeKcalInWorkouts, 40);
    expect(repo.sentRequests.single.toJson()['activeKcalInWorkouts'], 40);
    expect(controller.state.data!.displaySteps, 5200);
    expect(controller.state.data!.displayActiveKcal, 180);
    controller.dispose();
  });

  test('lỗi mạng khi lấy số máy chủ: vẫn hiện số của máy và vẫn gửi', () async {
    final service = FakeHealthConnectService()
      ..steps = 1200
      ..calories = 90;
    final repo = _TodayFailsRepository();
    final controller = HealthConnectController(
      service,
      activityRepository: repo,
      clock: () => DateTime(2026, 10, 19, 18),
      isPlatformSupportedOverride: () => true,
    );
    await pumpEventQueue();
    expect(controller.state.data!.displaySteps, 1200);
    expect(repo.sentRequests.single.activeKcalInWorkouts, isNull);
    expect(repo.sentRequests.single.toJson().containsKey('activeKcalInWorkouts'), isFalse);
    controller.dispose();
  });

  testWidgets('màn lịch sử hiện biểu đồ 7 ngày và từng ngày mới nhất trước', (
    tester,
  ) async {
    final repo = FakeActivityRepository()
      ..history = [
        for (var i = 1; i <= 8; i++)
          ActivityDay(
            localDate: '2026-10-${(11 + i).toString().padLeft(2, '0')}',
            steps: i == 8 ? 12000 : (i == 1 ? 0 : 4000),
            activeKcal: i == 8 ? 300 : 100,
            workoutKcal: i == 8 ? 150 : 0,
            totalBurnedKcal: i == 8 ? 410 : (i == 1 ? 0 : 100),
          ),
      ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activityRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ActivityHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('7 ngày gần nhất'), findsOneWidget);
    expect(find.text('12.0k'), findsOneWidget); // cột hôm nay
    // Trung bình các ngày có dữ liệu: (6×4000 + 12000) / 7
    expect(find.text('Trung bình 5142 bước/ngày (các ngày có dữ liệu)'), findsOneWidget);
    expect(find.text('T2 19/10'), findsOneWidget);
    expect(find.text('Tập 150 + đi lại 260 kcal'), findsOneWidget);
    final newest = tester.getTopLeft(find.text('T2 19/10')).dy;
    final older = tester.getTopLeft(find.text('CN 18/10')).dy;
    expect(newest, lessThan(older));
  });

  testWidgets('chưa có dữ liệu thì hướng dẫn kết nối', (tester) async {
    final repo = FakeActivityRepository()
      ..history = const [ActivityDay(localDate: '2026-10-19')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [activityRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: ActivityHistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Kết nối Health Connect'), findsOneWidget);
  });

  // Dùng HealthConnectService thật để chắc chắn không có buổi tập thì không gọi plugin
  test('service: không có buổi tập trả 0 mà không đọc Health Connect', () async {
    expect(await HealthConnectService().getActiveKcalInWindows(const []), 0);
  });
}

class _TodayFailsRepository extends FakeActivityRepository {
  @override
  Future<ActivityToday> getToday() async => throw Exception('offline');
}
