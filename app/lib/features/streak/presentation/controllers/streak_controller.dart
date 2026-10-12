import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/repositories/api_streak_repository.dart';
import '../../domain/models/streak_models.dart';
import '../../domain/repositories/streak_repository.dart';

import '../../../../core/utils/cache_for_extension.dart';
import '../../../users/presentation/controllers/user_controller.dart';

final streakRepositoryProvider = Provider<StreakRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiStreakRepository(client: client);
});

final streakFutureProvider = FutureProvider.autoDispose<StreakView>((
  ref,
) async {
  ref.cacheFor(const Duration(minutes: 5));
  try {
    final repo = ref.watch(streakRepositoryProvider);
    return await repo.getStreak();
  } catch (e) {
    final user = ref.read(currentUserProvider);
    return StreakView(
      currentWeeks: user?.streak?.currentWeeks ?? 0,
      bestWeeks: user?.streak?.bestWeeks ?? 0,
      freezesAvailable: user?.streak?.freezesAvailable ?? 0,
      weeks: const [],
    );
  }
});

final streakWeekDetailProvider = FutureProvider.autoDispose
    .family<StreakWeekDetail, String>((ref, weekStart) async {
      ref.cacheFor(const Duration(minutes: 5));
      final repo = ref.watch(streakRepositoryProvider);
      return await repo.getWeekDetail(weekStart);
    });
