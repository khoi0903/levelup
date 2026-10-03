import '../../domain/models/me_response.dart';
import '../../domain/repositories/user_repository.dart';

class FakeUserRepository implements UserRepository {
  final MeResponse? meResponse;
  final Exception? errorToThrow;

  FakeUserRepository({this.meResponse, this.errorToThrow});

  @override
  Future<MeResponse> getMe() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return meResponse ??
        const MeResponse(
          id: 'dev-user-id',
          displayName: 'Minh',
          timezone: 'Asia/Ho_Chi_Minh',
          localDate: '2026-10-03',
          weekStart: '2026-09-28',
          profile: UserProfile(
            goal: 'lose_fat',
          ),
          streak: UserStreak(
            currentWeeks: 5,
            bestWeeks: 5,
            freezesAvailable: 1,
          ),
        );
  }
}
