import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/utils/cache_for_extension.dart';
import '../../data/repositories/api_body_repository.dart';
import '../../domain/models/body_models.dart';
import '../../domain/repositories/body_repository.dart';

final bodyRepositoryProvider = Provider<BodyRepository>(
  (ref) => ApiBodyRepository(ref.watch(apiClientProvider)),
);

/// GET /me/body
final bodyStatsProvider = FutureProvider.autoDispose<BodyStats>((ref) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(bodyRepositoryProvider).getBody();
});

/// GET /me/muscles/week của tuần hiện tại (máy chủ tự chọn tuần).
final musclesWeekProvider = FutureProvider.autoDispose<MuscleWeek>((ref) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(bodyRepositoryProvider).getMusclesWeek();
});
