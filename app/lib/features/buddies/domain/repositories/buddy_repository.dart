import '../models/buddy_models.dart';

abstract class BuddyRepository {
  Future<BuddyTodayResponse> getToday();
  Future<InviteResponse> createInvite();
  Future<PairResponse> joinInvite(String code);
  Future<BuddyActionResponse> sendAction(String pairId, BuddyActionRequest request);
  Future<void> leavePair();
}
