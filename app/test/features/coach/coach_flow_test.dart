import 'dart:async';

import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/coach/data/sse/coach_sse_parser.dart';
import 'package:fitness_app/features/coach/domain/models/coach_models.dart';
import 'package:fitness_app/features/coach/data/repositories/fake_coach_repository.dart';
import 'package:fitness_app/features/coach/presentation/controllers/coach_controller.dart';
import 'package:fitness_app/features/coach/presentation/screens/coach_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Coach trả lời chậm: tin của người dùng phải hiện trước khi có trả lời.
class _SlowCoachRepository extends FakeCoachRepository {
  _SlowCoachRepository() : super(initialMessages: []);
  final reply = Completer<void>();

  @override
  Future<SendCoachResponse> sendMessage(String text) async {
    await reply.future;
    return super.sendMessage(text);
  }

  @override
  Stream<CoachStreamEvent> sendMessageStream(String text) async* {
    await reply.future;
    yield* super.sendMessageStream(text);
  }
}

void main() {
  group('CoachFlow (Tab Coach)', () {
    testWidgets(
      'Chưa có tin: coach chào trước; gửi thì tin hiện ngay, chờ trả lời',
      (tester) async {
        final repo = _SlowCoachRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [coachRepositoryProvider.overrideWithValue(repo)],
            child: const MaterialApp(home: CoachScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Mình là coach của bạn'), findsOneWidget);
        await tester.tap(
          find.byKey(
            const ValueKey('coach-suggestion-Hôm nay mình nên tập gì?'),
          ),
        );
        await tester.pump();

        expect(
          find.text('Hôm nay mình nên tập gì?'),
          findsOneWidget,
        ); // chưa có trả lời vẫn thấy tin mình
        expect(find.byKey(const ValueKey('coach-typing')), findsOneWidget);
        expect(find.textContaining('Mình là coach của bạn'), findsOneWidget); // câu chào vẫn ở đầu
      expect(find.byKey(const ValueKey('coach-suggestion-Tối nay ăn gì để đủ đạm?')), findsNothing); // gợi ý ẩn

        repo.reply.complete();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('coach-typing')), findsNothing);
        expect(find.textContaining('Coach đã nhận được tin'), findsOneWidget);
        expect(
          find.text('Hôm nay mình nên tập gì?'),
          findsOneWidget,
        ); // không bị trùng
      },
    );

    testWidgets('Renders message history and sends a new message', (
      tester,
    ) async {
      final fakeRepo = FakeCoachRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [coachRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: CoachScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AI Coach'), findsOneWidget);
      expect(
        find.textContaining('Mình là AI Coach của LevelUp'),
        findsOneWidget,
      );
      expect(find.text('Dùng buổi này'), findsOneWidget);

      // Enter message and send
      await tester.enterText(
        find.byType(TextField),
        'Hôm nay mình nên tập bài gì?',
      );
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Hôm nay mình nên tập bài gì?'), findsOneWidget);
      expect(find.textContaining('Coach đã nhận được tin'), findsOneWidget);
      expect(fakeRepo.lastSentText, 'Hôm nay mình nên tập bài gì?');
    });

    testWidgets(
      'Action card: Dùng buổi này calls applyAction and updates status',
      (tester) async {
        final fakeRepo = FakeCoachRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [coachRepositoryProvider.overrideWithValue(fakeRepo)],
            child: const MaterialApp(home: CoachScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Dùng buổi này'), findsOneWidget);

        // Tap 'Dùng buổi này'
        await tester.tap(find.text('Dùng buổi này'));
        await tester.pumpAndSettle();

        expect(find.text('Đã áp dụng vào kế hoạch'), findsOneWidget);
        expect(fakeRepo.lastAppliedMessageId, 'msg-2');
      },
    );

    testWidgets('Displays 429 COACH_LIMIT error banner when limit reached', (
      tester,
    ) async {
      final fakeRepo = FakeCoachRepository(
        errorToThrow: const ApiException(code: 'COACH_LIMIT', statusCode: 429),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [coachRepositoryProvider.overrideWithValue(fakeRepo)],
          child: const MaterialApp(home: CoachScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('coach-error-banner')), findsOneWidget);
      expect(
        find.text(
          'Hôm nay bạn đã dùng hết lượt nhắn tin với Coach. Hãy quay lại vào ngày mai nhé!',
        ),
        findsOneWidget,
      );
    });
  });
}
