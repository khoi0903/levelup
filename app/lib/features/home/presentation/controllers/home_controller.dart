import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';
import '../../../../core/utils/cache_for_extension.dart';
import '../../../../core/utils/fast_cache.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
import '../../../users/presentation/controllers/user_controller.dart';
import '../../../workout/domain/models/workout_draft.dart';
import '../../../workout/domain/repositories/workout_draft_repository.dart';
import '../../../workout/domain/repositories/workout_repository.dart';
import '../../../workout/presentation/controllers/workout_controller.dart';

final currentPlanProvider = StateProvider<PlanView?>((ref) => null);

final homePlanProvider = FutureProvider.autoDispose<PlanView>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(planRepositoryProvider);
  final plan = await repo.getCurrentPlan();
  ref.read(currentPlanProvider.notifier).state = plan;
  try {
    final authUser = ref.read(authRepositoryProvider).currentUser;
    final uid = authUser?.id ?? ref.read(currentUserProvider)?.id;
    if (uid != null) {
      unawaited(FastCache.savePlan(uid, plan));
    }
  } catch (_) {
    final uid = ref.read(currentUserProvider)?.id;
    if (uid != null) {
      unawaited(FastCache.savePlan(uid, plan));
    }
  }
  return plan;
});

final activeWorkoutDraftProvider =
    FutureProvider.autoDispose<WorkoutDraft?>((ref) async {
  final repo = ref.watch(workoutDraftRepositoryProvider);
  final now = ref.watch(workoutClockProvider)();
  // Quá 12 giờ tự xóa
  await repo.deleteExpiredDrafts(now, maxAge: const Duration(hours: 12));
  return repo.getActiveDraft();
});

Future<bool> syncPendingWorkoutDrafts({
  required WorkoutDraftRepository draftRepo,
  required WorkoutRepository workoutRepo,
  required DateTime now,
  void Function()? onSuccess,
}) async {
  await draftRepo.deleteExpiredDrafts(now, maxAge: const Duration(hours: 12));
  final pendings = await draftRepo.getPendingSubmitDrafts();
  var anySuccess = false;
  for (final draft in pendings) {
    try {
      final request = draft.toWorkoutRequest();
      await workoutRepo.saveWorkout(request);
      await draftRepo.deleteDraft(draft.clientId);
      anySuccess = true;
    } catch (_) {
      // Giữ nguyên pending_submit
    }
  }
  if (anySuccess && onSuccess != null) {
    onSuccess();
  }
  return anySuccess;
}

Future<bool> triggerSyncPendingWorkoutDrafts(WidgetRef ref) async {
  try {
    return await syncPendingWorkoutDrafts(
      draftRepo: ref.read(workoutDraftRepositoryProvider),
      workoutRepo: ref.read(workoutRepositoryProvider),
      now: ref.read(workoutClockProvider)(),
      onSuccess: () {
        ref.invalidate(homePlanProvider);
        ref.invalidate(userStatusFutureProvider);
        ref.invalidate(activeWorkoutDraftProvider);
      },
    );
  } catch (e) {
    debugPrint('triggerSyncPendingWorkoutDrafts error: $e');
    return false;
  }
}
