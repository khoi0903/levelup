import '../../domain/repositories/demo_repository.dart';

class FakeDemoRepository implements DemoRepository {
  Map<String, dynamic>? mockResult;
  Exception? errorToThrow;
  String? lastActionCalled;

  FakeDemoRepository({this.mockResult, this.errorToThrow});

  @override
  Future<Map<String, dynamic>> executeAction(String action) async {
    lastActionCalled = action;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return mockResult ??
        {
          'action': action,
          'result': switch (action) {
            'checkin' || 'push-test' => {'result': 'SENT'},
            'seed' => {'workouts': 9, 'currentWeeks': 3, 'measurements': 4, 'meals': 21},
            'skip-two' => {'skipped': 2, 'notified': true},
            _ => <String, dynamic>{},
          },
        };
  }
}
