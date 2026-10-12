import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/repositories/api_progress_repository.dart';
import '../../domain/models/progress_models.dart';
import '../../domain/repositories/progress_repository.dart';

import '../../../../core/utils/cache_for_extension.dart';

final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => ApiProgressRepository(ref.watch(apiClientProvider)),
);
final measurementHistoryProvider =
    FutureProvider.autoDispose<MeasurementHistory>(
      (ref) {
        ref.cacheFor(const Duration(minutes: 5));
        return ref.watch(progressRepositoryProvider).history(days: 90);
      },
    );
final newProgressAchievementsProvider =
    StateProvider<List<ProgressAchievement>>((ref) => []);
