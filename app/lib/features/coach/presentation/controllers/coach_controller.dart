import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../data/repositories/api_coach_repository.dart';
import '../../data/sse/coach_sse_parser.dart';
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
  final bool hasStreamingReply;
  final bool isLoadingMore;
  final String? nextBefore;
  final int remainingToday;
  final dynamic error;

  const CoachChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.hasStreamingReply = false,
    this.isLoadingMore = false,
    this.nextBefore,
    this.remainingToday = 10,
    this.error,
  });

  CoachChatState copyWith({
    List<CoachMessageView>? messages,
    bool? isLoading,
    bool? isSending,
    bool? hasStreamingReply,
    bool? isLoadingMore,
    String? nextBefore,
    bool clearNextBefore = false,
    int? remainingToday,
    dynamic error,
    bool clearError = false,
  }) {
    return CoachChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      hasStreamingReply: hasStreamingReply ?? this.hasStreamingReply,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      // Hết lịch sử cũ: phải xóa được nextBefore (null), không giữ mốc cũ
      nextBefore: clearNextBefore ? null : (nextBefore ?? this.nextBefore),
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
      final pendingMessages = state.messages
          .where((m) => m.id.startsWith('pending-') || m.id.startsWith('streaming-'))
          .toList();
      state = state.copyWith(
        isLoading: false,
        messages: [...pendingMessages, ...res.messages],
        nextBefore: res.nextBefore,
        clearNextBefore: res.nextBefore == null,
        remainingToday: res.remainingToday,
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
        clearNextBefore: res.nextBefore == null,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e);
    }
  }

  /// Gửi tin nhắn:
  /// - Tin người dùng hiện ngay với id "pending-..."
  /// - Bong bóng coach xuất hiện và chữ lớn dần theo từng delta (bỏ "Coach đang trả lời...")
  /// - Event done: thay cả hai tin bằng bản từ server, cập nhật remainingToday
  /// - Lỗi giữa chừng / error: gỡ tin tạm, trả chữ vào ô nhập, hiện lỗi
  /// - 404: dùng POST /coach/messages (fallback cũ)
  Future<bool> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.isSending) return false;

    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pending = CoachMessageView(
      id: pendingId,
      role: 'user',
      content: trimmed,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      isSending: true,
      hasStreamingReply: false,
      clearError: true,
      messages: [pending, ...state.messages],
    );

    final streamingReplyId = 'streaming-${DateTime.now().microsecondsSinceEpoch}';
    var accumulatedDelta = '';
    var hasReceivedDelta = false;

    List<CoachMessageView> currentBaseMessages() => state.messages
        .where((m) => m.id != pendingId && m.id != streamingReplyId)
        .toList();

    try {
      await for (final event in _repository.sendMessageStream(trimmed)) {
        if (event is CoachDeltaEvent) {
          accumulatedDelta += event.text;
          hasReceivedDelta = true;
          final streamingMessage = CoachMessageView(
            id: streamingReplyId,
            role: 'coach',
            content: accumulatedDelta,
            createdAt: DateTime.now(),
          );
          state = state.copyWith(
            hasStreamingReply: true,
            messages: [streamingMessage, pending, ...currentBaseMessages()],
          );
        } else if (event is CoachDoneEvent) {
          final res = event.response;
          state = state.copyWith(
            isSending: false,
            hasStreamingReply: false,
            messages: [res.reply, res.userMessage, ...currentBaseMessages()],
            remainingToday: res.remainingToday,
          );
          return true;
        } else if (event is CoachErrorEvent) {
          throw ApiException(code: event.code);
        }
      }

      if (hasReceivedDelta) {
        state = state.copyWith(isSending: false, hasStreamingReply: false);
        return true;
      }
      return true;
    } on ApiException catch (e) {
      if (e.statusCode == 404) {
        // Fallback to POST /coach/messages
        try {
          final res = await _repository.sendMessage(trimmed);
          state = state.copyWith(
            isSending: false,
            hasStreamingReply: false,
            messages: [res.reply, res.userMessage, ...currentBaseMessages()],
            remainingToday: res.remainingToday,
          );
          return true;
        } catch (err) {
          state = state.copyWith(
            isSending: false,
            hasStreamingReply: false,
            error: err,
            messages: currentBaseMessages(),
          );
          return false;
        }
      }
      state = state.copyWith(
        isSending: false,
        hasStreamingReply: false,
        error: e,
        messages: currentBaseMessages(),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        hasStreamingReply: false,
        error: e,
        messages: currentBaseMessages(),
      );
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
