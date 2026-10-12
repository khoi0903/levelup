import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../data/repositories/api_review_repository.dart';
import '../../domain/models/review_models.dart';
import '../../domain/repositories/review_repository.dart';

import '../../../../core/utils/cache_for_extension.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiReviewRepository(client: client);
});

final latestReviewFutureProvider = FutureProvider.autoDispose<WeeklyReviewView>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(reviewRepositoryProvider);
  return repo.getLatestReview();
});

class ReviewDecisionState {
  final bool isSubmitting;
  final PlanView? activePlan;
  final dynamic error;

  const ReviewDecisionState({
    this.isSubmitting = false,
    this.activePlan,
    this.error,
  });

  ReviewDecisionState copyWith({
    bool? isSubmitting,
    PlanView? activePlan,
    dynamic error,
    bool clearError = false,
  }) {
    return ReviewDecisionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      activePlan: activePlan ?? this.activePlan,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ReviewDecisionNotifier extends StateNotifier<ReviewDecisionState> {
  final ReviewRepository _repository;
  final Ref _ref;

  ReviewDecisionNotifier(this._repository, this._ref) : super(const ReviewDecisionState());

  Future<PlanView?> acceptReview(String reviewId) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final res = await _repository.submitDecision(
        reviewId,
        const ReviewDecisionRequest(decision: 'accepted'),
      );
      state = state.copyWith(isSubmitting: false, activePlan: res);
      _ref.invalidate(latestReviewFutureProvider);
      return res;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
      return null;
    }
  }

  Future<PlanView?> adjustReview(
    String reviewId, {
    required int sessionsPerWeek,
    required int sessionMinutes,
  }) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final res = await _repository.submitDecision(
        reviewId,
        ReviewDecisionRequest(
          decision: 'adjusted',
          adjustments: ReviewAdjustments(
            sessionsPerWeek: sessionsPerWeek,
            sessionMinutes: sessionMinutes,
          ),
        ),
      );
      state = state.copyWith(isSubmitting: false, activePlan: res);
      _ref.invalidate(latestReviewFutureProvider);
      return res;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
      return null;
    }
  }
}

final reviewDecisionControllerProvider =
    StateNotifierProvider.autoDispose<ReviewDecisionNotifier, ReviewDecisionState>((ref) {
  final repo = ref.watch(reviewRepositoryProvider);
  return ReviewDecisionNotifier(repo, ref);
});
