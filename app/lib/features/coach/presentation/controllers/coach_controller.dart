import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../data/repositories/api_coach_repository.dart';
import '../../domain/models/coach_models.dart';
import '../../domain/repositories/coach_repository.dart';

final coachRepositoryProvider = Provider<CoachRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiCoachRepository(client: client);
});

class CoachChatState {
  final List<CoachMessageView> messages;
  final bool isLoading;
  final bool isSending;
  final bool isLoadingMore;
  final String? nextBefore;
  final int remainingToday;
  final dynamic error;

  const CoachChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isLoadingMore = false,
    this.nextBefore,
    this.remainingToday = 10,
    this.error,
  });

  CoachChatState copyWith({
    List<CoachMessageView>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isLoadingMore,
    String? nextBefore,
    int? remainingToday,
    dynamic error,
    bool clearError = false,
  }) {
    return CoachChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextBefore: nextBefore ?? this.nextBefore,
      remainingToday: remainingToday ?? this.remainingToday,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class CoachChatNotifier extends StateNotifier<CoachChatState> {
  final CoachRepository _repository;

  CoachChatNotifier(this._repository) : super(const CoachChatState()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _repository.getHistory(limit: 20);
      state = state.copyWith(
        isLoading: false,
        messages: res.messages,
        nextBefore: res.nextBefore,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.nextBefore == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final res = await _repository.getHistory(
        before: state.nextBefore,
        limit: 20,
      );
      state = state.copyWith(
        isLoadingMore: false,
        messages: [...state.messages, ...res.messages],
        nextBefore: res.nextBefore,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  /// Tin của người dùng hiện ngay (id "pending-..."), coach trả lời xong thì thay bằng bản từ server.
  /// Gửi lỗi thì gỡ tin tạm ra, màn hình trả lại chữ vào ô nhập.
  Future<bool> sendMessage(String text) async {
    if (text.trim().isEmpty || state.isSending) return false;
    final pending = CoachMessageView(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      role: 'user',
      content: text.trim(),
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      isSending: true,
      clearError: true,
      messages: [pending, ...state.messages],
    );
    List<CoachMessageView> rest() =>
        state.messages.where((m) => m.id != pending.id).toList();
    try {
      final res = await _repository.sendMessage(text.trim());
      state = state.copyWith(
        isSending: false,
        messages: [res.reply, res.userMessage, ...rest()],
        remainingToday: res.remainingToday,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSending: false, error: e, messages: rest());
      return false;
    }
  }

  Future<bool> applyAction(String messageId) async {
    try {
      await _repository.applyAction(messageId);
      final updated = state.messages.map((m) {
        if (m.id == messageId && m.card != null) {
          return m.copyWith(card: m.card!.copyWith(status: 'applied'));
        }
        return m;
      }).toList();
      state = state.copyWith(messages: updated);
      return true;
    } catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }
}

final coachChatProvider =
    StateNotifierProvider.autoDispose<CoachChatNotifier, CoachChatState>((ref) {
      final repo = ref.watch(coachRepositoryProvider);
      return CoachChatNotifier(repo);
    });
