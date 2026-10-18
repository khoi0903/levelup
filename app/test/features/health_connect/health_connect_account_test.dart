import 'package:fitness_app/features/activity/data/repositories/fake_activity_repository.dart';
import 'package:fitness_app/features/health_connect/data/services/health_connect_links.dart';
import 'package:fitness_app/features/health_connect/domain/models/health_connect_state.dart';
import 'package:fitness_app/features/health_connect/presentation/controllers/health_connect_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../activity/activity_mobility_test.dart' show FakeHealthConnectService;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeHealthConnectService service;
  late FakeActivityRepository activity;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = FakeHealthConnectService()
      ..steps = 5200
      ..calories = 180;
    activity = FakeActivityRepository();
  });

  HealthConnectController controller(String? uid) => HealthConnectController(
    service,
    uid: uid,
    links: HealthConnectLinks(),
    activityRepository: activity,
    clock: () => DateTime(2026, 10, 18, 9),
    isPlatformSupportedOverride: () => true,
  );

  test('tài khoản khác cùng máy không đọc, không gửi số bước', () async {
    final a = controller('uid-a');
    await pumpEventQueue();
    expect(a.state.status, HealthConnectStatus.notAuthorized);
    expect(await a.connect(), isTrue);
    expect(a.state.data!.steps, 5200);
    expect(activity.sentRequests, hasLength(1));
    a.dispose();

    // Đăng xuất, đăng nhập tài khoản B: máy vẫn có quyền nhưng B chưa tự kết nối
    final b = controller('uid-b');
    await pumpEventQueue();
    expect(b.state.status, HealthConnectStatus.notAuthorized);
    await b.refreshTodayData();
    expect(b.state.data, isNull);
    expect(activity.sentRequests, hasLength(1));
    b.dispose();

    // A đăng nhập lại: không phải kết nối lại
    final again = controller('uid-a');
    await pumpEventQueue();
    expect(again.state.status, HealthConnectStatus.authorized);
    expect(again.state.data!.steps, 5200);
    again.dispose();
  });

  test('chưa đăng nhập thì không kết nối được', () async {
    final c = controller(null);
    await pumpEventQueue();
    expect(c.state.status, HealthConnectStatus.notAuthorized);
    expect(await c.connect(), isFalse);
    expect(activity.sentRequests, isEmpty);
    c.dispose();
  });
}
