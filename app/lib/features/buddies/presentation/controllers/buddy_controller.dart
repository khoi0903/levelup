import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../data/repositories/api_buddy_repository.dart';
import '../../domain/models/buddy_models.dart';
import '../../domain/repositories/buddy_repository.dart';

import '../../../../core/utils/cache_for_extension.dart';

final buddyRepositoryProvider = Provider<BuddyRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiBuddyRepository(client: client);
});

final buddyTodayFutureProvider = FutureProvider.autoDispose<BuddyTodayResponse?>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));
  final repo = ref.watch(buddyRepositoryProvider);
  try {
    return await repo.getToday();
  } catch (e) {
    // If not paired or NO_BUDDY, return null
    return null;
  }
});

class BuddyState {
  final bool isLoading;
  final bool isActionLoading;
  final InviteResponse? currentInvite;
  final String? actionSuccessMessage;
  final dynamic error;

  const BuddyState({
    this.isLoading = false,
    this.isActionLoading = false,
    this.currentInvite,
    this.actionSuccessMessage,
    this.error,
  });

  BuddyState copyWith({
    bool? isLoading,
    bool? isActionLoading,
    InviteResponse? currentInvite,
    String? actionSuccessMessage,
    dynamic error,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return BuddyState(
      isLoading: isLoading ?? this.isLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      currentInvite: currentInvite ?? this.currentInvite,
      actionSuccessMessage:
          clearSuccess ? null : (actionSuccessMessage ?? this.actionSuccessMessage),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BuddyNotifier extends StateNotifier<BuddyState> {
  final BuddyRepository _repository;
  final Ref _ref;

  BuddyNotifier(this._repository, this._ref) : super(const BuddyState());

  Future<InviteResponse?> createInvite() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final res = await _repository.createInvite();
      state = state.copyWith(isLoading: false, currentInvite: res);
      return res;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
      return null;
    }
  }

  Future<PairResponse?> joinInvite(String code) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      final res = await _repository.joinInvite(code.trim());
      state = state.copyWith(
        isLoading: false,
        actionSuccessMessage: 'Ghép cặp thành công với ${res.buddyName}!',
      );
      _ref.invalidate(buddyTodayFutureProvider);
      return res;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
      return null;
    }
  }

  Future<bool> sendNudge(String pairId) async {
    state = state.copyWith(isActionLoading: true, clearError: true, clearSuccess: true);
    try {
      await _repository.sendAction(
        pairId,
        const BuddyActionRequest(type: 'nudge'),
      );
      state = state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'Đã gửi lời nhắc tập tới bạn đồng hành!',
      );
      _ref.invalidate(buddyTodayFutureProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e);
      return false;
    }
  }

  Future<bool> sendCheer(String pairId) async {
    state = state.copyWith(isActionLoading: true, clearError: true, clearSuccess: true);
    try {
      await _repository.sendAction(
        pairId,
        const BuddyActionRequest(type: 'cheer'),
      );
      state = state.copyWith(
        isActionLoading: false,
        actionSuccessMessage: 'Đã gửi lời cổ vũ tới bạn đồng hành! 🔥',
      );
      _ref.invalidate(buddyTodayFutureProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isActionLoading: false, error: e);
      return false;
    }
  }

  Future<bool> leavePair() async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);
    try {
      await _repository.leavePair();
      state = state.copyWith(
        isLoading: false,
        actionSuccessMessage: 'Đã rời khỏi cặp đồng hành.',
      );
      _ref.invalidate(buddyTodayFutureProvider);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
      return false;
    }
  }
}

final buddyControllerProvider =
    StateNotifierProvider.autoDispose<BuddyNotifier, BuddyState>((ref) {
  final repo = ref.watch(buddyRepositoryProvider);
  return BuddyNotifier(repo, ref);
});
