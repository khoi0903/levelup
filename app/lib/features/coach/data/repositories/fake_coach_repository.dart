import '../../../onboarding/domain/models/plan_models.dart';
import '../../domain/models/coach_models.dart';
import '../../domain/repositories/coach_repository.dart';

class FakeCoachRepository implements CoachRepository {
  List<CoachMessageView> messages;
  String? nextBefore;
  int remainingToday;
  Exception? errorToThrow;
  String? lastSentText;
  String? lastAppliedMessageId;

  FakeCoachRepository({
    List<CoachMessageView>? initialMessages,
    this.nextBefore,
    this.remainingToday = 10,
    this.errorToThrow,
  }) : messages = initialMessages ??
            [
              CoachMessageView(
                id: 'msg-1',
                role: 'coach',
                content:
                    'Chào bạn! Mình là AI Coach của LevelUp. Hôm nay bạn cần hỗ trợ gì về kế hoạch tập luyện hay động tác nào không?',
                createdAt: DateTime.now().subtract(const Duration(hours: 2)),
              ),
              CoachMessageView(
                id: 'msg-2',
                role: 'coach',
                content:
                    'Mình thấy lưng dưới của bạn hơi mỏi. Mình đề xuất đổi bài Deadlift sang Glute Bridge nhé?',
                createdAt: DateTime.now().subtract(const Duration(hours: 1)),
                card: const CoachCardView(
                  type: 'adjust_session',
                  status: 'proposed',
                  planId: 'plan-1',
                  sessionId: 'session-1',
                  change: 'Đổi bài tập lưng an toàn hơn',
                  fromExerciseName: 'Deadlift',
                  toExerciseName: 'Glute Bridge',
                  reason: 'Giảm áp lực lên lưng dưới',
                ),
              ),
            ];

  @override
  Future<CoachHistoryResponse> getHistory({String? before, int limit = 20}) async {
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return CoachHistoryResponse(
      messages: List.from(messages),
      nextBefore: nextBefore,
    );
  }

  @override
  Future<SendCoachResponse> sendMessage(String text) async {
    lastSentText = text;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    final userMsg = CoachMessageView(
      id: 'user-msg-${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );
    final replyMsg = CoachMessageView(
      id: 'coach-reply-${DateTime.now().millisecondsSinceEpoch}',
      role: 'coach',
      content: 'Coach đã nhận được tin: "$text". Bạn cứ tiếp tục duy trì nhé!',
      createdAt: DateTime.now().add(const Duration(seconds: 1)),
    );

    messages.insert(0, replyMsg);
    messages.insert(1, userMsg);
    remainingToday = (remainingToday - 1).clamp(0, 100);

    return SendCoachResponse(
      userMessage: userMsg,
      reply: replyMsg,
      remainingToday: remainingToday,
      source: 'rules',
    );
  }

  @override
  Future<PlanView> applyAction(String messageId) async {
    lastAppliedMessageId = messageId;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }

    // Update status in messages
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx != -1 && messages[idx].card != null) {
      messages[idx] = messages[idx].copyWith(
        card: messages[idx].card!.copyWith(status: 'applied'),
      );
    }

    return const PlanView(
      id: 'plan-1',
      weekStart: '2026-09-28',
      status: 'active',
      targetSessions: 3,
      sessions: [
        SessionView(
          id: 'session-1',
          scheduledDate: '2026-10-04',
          scheduledTime: '18:30',
          title: 'Toàn thân (Đã đổi Glute Bridge)',
          durationMin: 15,
          status: 'planned',
          adjustedReason: 'coach_action',
        ),
      ],
    );
  }
}
