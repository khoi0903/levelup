import 'dart:async';

import 'package:fitness_app/features/coach/data/repositories/fake_coach_repository.dart';
import 'package:fitness_app/features/coach/data/sse/coach_sse_parser.dart';
import 'package:fitness_app/features/coach/domain/models/coach_models.dart';
import 'package:fitness_app/features/coach/presentation/controllers/coach_controller.dart';
import 'package:fitness_app/features/coach/presentation/screens/coach_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Coach Stream Flow', () {
    test(
      'CoachChatNotifier: delta từng bước làm chữ lớn dần, done thay bằng server reply',
      () async {
        final streamController = StreamController<CoachStreamEvent>();
        final repo = FakeCoachRepository(
          initialMessages: [],
          customStreamHandler: (text) => streamController.stream,
        );

        final notifier = CoachChatNotifier(repo);
        await Future<void>.delayed(Duration.zero);

        final sendFuture = notifier.sendMessage('Chào Coach');
        await Future<void>.delayed(Duration.zero);

        // 1. Tin người dùng hiện ngay với id pending
        expect(notifier.state.isSending, isTrue);
        expect(notifier.state.hasStreamingReply, isFalse);
        expect(notifier.state.messages, hasLength(1));
        expect(notifier.state.messages.first.role, 'user');
        expect(notifier.state.messages.first.content, 'Chào Coach');

        // 2. Delta đầu tiên tới -> bong bóng coach xuất hiện
        streamController.add(const CoachDeltaEvent('Chào Khôi, '));
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state.hasStreamingReply, isTrue);
        expect(notifier.state.messages, hasLength(2));
        expect(notifier.state.messages.first.role, 'coach');
        expect(notifier.state.messages.first.content, 'Chào Khôi, ');

        // 3. Delta thứ hai tới -> chữ ghép lớn dần
        streamController.add(const CoachDeltaEvent('hôm nay thế nào?'));
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state.messages.first.content, 'Chào Khôi, hôm nay thế nào?');

        // 4. Done event -> thay thế bằng bản server
        final doneResponse = SendCoachResponse(
          userMessage: CoachMessageView(
            id: 'real-user-1',
            role: 'user',
            content: 'Chào Coach',
            createdAt: DateTime.now(),
          ),
          reply: CoachMessageView(
            id: 'real-coach-1',
            role: 'coach',
            content: 'Chào Khôi, hôm nay bạn thấy thế nào? Sẵn sàng tập chưa?',
            createdAt: DateTime.now(),
          ),
          remainingToday: 7,
          source: 'claude',
        );
        streamController.add(CoachDoneEvent(doneResponse));
        await streamController.close();

        final result = await sendFuture;
        expect(result, isTrue);
        expect(notifier.state.isSending, isFalse);
        expect(notifier.state.hasStreamingReply, isFalse);
        expect(notifier.state.messages.first.id, 'real-coach-1');
        expect(
          notifier.state.messages.first.content,
          'Chào Khôi, hôm nay bạn thấy thế nào? Sẵn sàng tập chưa?',
        );
        expect(notifier.state.remainingToday, 7);
      },
    );

    testWidgets(
      'UI: delta -> done thay tin: chữ lớn dần theo delta, done thay bằng server reply',
      (tester) async {
        final repo = FakeCoachRepository(
          initialMessages: [],
          streamDeltas: ['Chào bạn, ', 'hôm nay thế nào?'],
          streamDoneResponse: SendCoachResponse(
            userMessage: CoachMessageView(
              id: 'real-user-1',
              role: 'user',
              content: 'Chào Coach',
              createdAt: DateTime.now(),
            ),
            reply: CoachMessageView(
              id: 'real-coach-1',
              role: 'coach',
              content: 'Chào bạn, hôm nay thế nào? Sẵn sàng tập chưa?',
              createdAt: DateTime.now(),
            ),
            remainingToday: 7,
            source: 'claude',
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [coachRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: CoachScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Gõ tin nhắn
        await tester.enterText(find.byType(TextField), 'Chào Coach');
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();

        expect(
          find.text('Chào bạn, hôm nay thế nào? Sẵn sàng tập chưa?'),
          findsOneWidget,
        );
        expect(find.text('Còn 7 lượt hôm nay'), findsOneWidget);
        expect(find.byKey(const ValueKey('coach-typing')), findsNothing);
      },
    );

    testWidgets(
      'error giữa chừng: gỡ bong bóng tạm, trả chữ vào ô nhập, hiện mapErrorMessage',
      (tester) async {
        final repo = FakeCoachRepository(
          initialMessages: [],
          streamDeltas: ['Đang viết...'],
          streamError: const CoachErrorEvent(code: 'COACH_LIMIT'),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [coachRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: CoachScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Tin nhắn thử lỗi');
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();

        // Bong bóng tạm và tin user tạm bị gỡ
        expect(find.text('Đang viết...'), findsNothing);
        // Trả chữ vào ô nhập
        expect(find.text('Tin nhắn thử lỗi'), findsOneWidget);
        // Hiện thông báo lỗi
        expect(find.byKey(const ValueKey('coach-error-banner')), findsOneWidget);
        expect(
          find.text(
            'Hôm nay bạn đã dùng hết lượt nhắn tin với Coach. Hãy quay lại vào ngày mai nhé!',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '404 từ endpoint stream: dùng endpoint cũ POST /coach/messages',
      (tester) async {
        final repo = FakeCoachRepository(
          initialMessages: [],
          streamReturns404: true, // Mock 404 stream endpoint
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [coachRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: CoachScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Hỏi khi 404');
        await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
        await tester.pumpAndSettle();

        // 404 stream endpoint fallback sang sendMessage thành công
        expect(find.text('Hỏi khi 404'), findsOneWidget);
        expect(find.textContaining('Coach đã nhận được tin: "Hỏi khi 404"'), findsOneWidget);
        expect(repo.lastSentText, 'Hỏi khi 404');
      },
    );
  });
}
