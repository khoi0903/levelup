import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/api_activity_repository.dart';
import '../../domain/models/activity_models.dart';

/// Số ngày hiện trên màn lịch sử bước chân.
const activityHistoryDays = 30;

final activityHistoryProvider = FutureProvider.autoDispose<List<ActivityDay>>(
  (ref) => ref.watch(activityRepositoryProvider).getHistory(activityHistoryDays),
);
