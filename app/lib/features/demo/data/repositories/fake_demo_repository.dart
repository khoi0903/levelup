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
          'result': action == 'checkin' || action == 'push-test'
              ? {'result': 'SENT'}
              : {},
        };
  }
}
