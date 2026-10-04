import '../../domain/models/buddy_models.dart';
import '../../domain/repositories/buddy_repository.dart';

class FakeBuddyRepository implements BuddyRepository {
  BuddyTodayResponse? todayResponse;
  InviteResponse? inviteResponse;
  PairResponse? pairResponse;
  Exception? errorToThrow;
  String? lastJoinCode;
  String? lastActionType;
  bool isPairLeft = false;

  FakeBuddyRepository({
    BuddyTodayResponse? initialToday,
    this.inviteResponse,
    this.pairResponse,
    this.errorToThrow,
  }) : todayResponse = initialToday ??
            const BuddyTodayResponse(
              pairId: 'pair-123',
              sharedStreakWeeks: 3,
              buddy: BuddyInfo(
                displayName: 'Lan',
                localDate: '2026-10-04',
                status: 'planned',
                scheduledTime: '19:00',
                sessionTitle: 'Toàn thân 15 phút',
                streakWeeks: 3,
                week: BuddyWeekInfo(
                  weekStart: '2026-09-28',
                  completedSessions: 2,
                  targetSessions: 3,
                ),
              ),
              myActionsToday: BuddyMyActions(nudged: false, cheered: false),
              shared: BuddySharedInfo(weightKg: 52.5, mealsKcalToday: 1350),
            );

  @override
  Future<BuddyTodayResponse> getToday() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (isPairLeft || todayResponse == null) {
      throw Exception('NO_BUDDY');
    }
    return todayResponse!;
  }

  @override
  Future<InviteResponse> createInvite() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return inviteResponse ??
        InviteResponse(
          code: 'LV8899',
          expiresAt: DateTime.now().add(const Duration(days: 7)),
          shareText:
              'Cùng tập luyện với mình trên LevelUp nhé! Nhập mã mời LV8899 để ghép cặp đồng hành.',
        );
  }

  @override
  Future<PairResponse> joinInvite(String code) async {
    lastJoinCode = code;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    isPairLeft = false;
    return pairResponse ??
        PairResponse(
          pairId: 'pair-new',
          buddyName: 'Minh Anh',
          since: DateTime.now(),
        );
  }

  @override
  Future<BuddyActionResponse> sendAction(String pairId, BuddyActionRequest request) async {
    lastActionType = request.type;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    if (todayResponse != null) {
      todayResponse = todayResponse!.copyWith(
        myActionsToday: todayResponse!.myActionsToday.copyWith(
          nudged: request.type == 'nudge' ? true : todayResponse!.myActionsToday.nudged,
          cheered: request.type == 'cheer' ? true : todayResponse!.myActionsToday.cheered,
        ),
      );
    }
    return BuddyActionResponse(type: request.type, localDate: '2026-10-04');
  }

  @override
  Future<void> leavePair() async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    isPairLeft = true;
    todayResponse = null;
  }
}
