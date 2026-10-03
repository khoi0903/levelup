import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../data/repositories/api_user_repository.dart';
import '../../domain/models/me_response.dart';
import '../../domain/repositories/user_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiUserRepository(client);
});

final currentUserProvider = StateProvider<MeResponse?>((ref) => null);

final userStatusFutureProvider =
    FutureProvider.autoDispose<MeResponse>((ref) async {
  final repo = ref.watch(userRepositoryProvider);
  final me = await repo.getMe();
  ref.read(currentUserProvider.notifier).state = me;
  return me;
});
