import '../../../../core/api/api_client.dart';
import '../../domain/models/buddy_models.dart';
import '../../domain/repositories/buddy_repository.dart';

class ApiBuddyRepository implements BuddyRepository {
  final ApiClient client;

  ApiBuddyRepository({required this.client});

  @override
  Future<BuddyTodayResponse> getToday() async {
    final response = await client.get<Map<String, dynamic>>('/buddies/today');
    return BuddyTodayResponse.fromJson(response.data!);
  }

  @override
  Future<InviteResponse> createInvite() async {
    final response = await client.post<Map<String, dynamic>>('/buddies/invites');
    return InviteResponse.fromJson(response.data!);
  }

  @override
  Future<PairResponse> joinInvite(String code) async {
    final response = await client.post<Map<String, dynamic>>(
      '/buddies/join',
      data: {'code': code},
    );
    return PairResponse.fromJson(response.data!);
  }

  @override
  Future<BuddyActionResponse> sendAction(String pairId, BuddyActionRequest request) async {
    final response = await client.post<Map<String, dynamic>>(
      '/buddies/$pairId/actions',
      data: request.toJson(),
    );
    return BuddyActionResponse.fromJson(response.data!);
  }

  @override
  Future<void> leavePair() async {
    await client.delete<void>('/buddies/pair');
  }
}
