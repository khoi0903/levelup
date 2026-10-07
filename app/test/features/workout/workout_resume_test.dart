import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/workout/data/repositories/memory_workout_draft_repository.dart';
import 'package:fitness_app/features/workout/domain/models/workout_draft.dart';
import 'package:fitness_app/features/workout/domain/models/workout_models.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:fitness_app/features/workout/presentation/screens/workout_active_screen.dart';
import 'package:fitness_app/features/workout/presentation/screens/workout_start_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test_helpers.dart';

void main() {
  group('Workout Resume Flow (Tiếp tục buổi tập)', () {
    late MemoryWorkoutDraftRepository draftRepo;
    late PlanView testPlan;

    setUp(() {
      draftRepo = MemoryWorkoutDraftRepository();
      testPlan = planWith(const [
        ItemView(exerciseId: squatId, sets: 2, reps: 10, restSec: 45),
        ItemView(exerciseId: plankId, sets: 1, durationSec: 30),
      ]);
    });

    WorkoutSessionState createIncompleteState({
      required SessionView session,
      String clientId = 'client-12345678901234567890',
      DateTime? startedAt,
      int setsLogged = 1,
    }) {
      final items = [
        WorkoutPlanItem.from(session.items[0], testExercises[0]),
        WorkoutPlanItem.from(session.items[1], testExercises[1]),
      ];
      final sets = <SetLog>[
        if (setsLogged >= 1)
          const SetLog(exerciseId: squatId, setIndex: 1, reps: 10),
      ];
      return WorkoutSessionState(
        session: session,
        items: items,
        clientId: clientId,
        startedAt: startedAt ?? DateTime.utc(2026, 10, 5, 10, 0, 0),
        exerciseIndex: setsLogged >= 2 ? 1 : 0,
        setNumber: setsLogged == 1 ? 2 : 1,
        sets: sets,
      );
    }

    testWidgets(
      'Có nháp cùng buổi → hiện dialog, "Tiếp tục" vào đúng bài/hiệp với các hiệp đã ghi và giữ nguyên startedAt, clientId',
      (tester) async {
        final harness = WorkoutHarness(plan: testPlan, draftRepo: draftRepo);
        final session = testPlan.sessions.first;
        final origStartedAt = DateTime.utc(2026, 10, 5, 9, 30, 0);
        const origClientId = 'client-resume-test-123456';

        final sState = createIncompleteState(
          session: session,
          clientId: origClientId,
          startedAt: origStartedAt,
          setsLogged: 1,
        );

        await draftRepo.saveDraft(
          WorkoutDraft(
            clientId: sState.clientId,
            sessionId: session.id,
            stateJson: WorkoutDraft.encodeStateJson(sState),
            updatedAt: harness.clock.now.subtract(const Duration(minutes: 30)),
            status: 'active',
          ),
        );

        // Mở màn bắt đầu buổi
        await harness.pump(tester, '/workout/${session.id}');

        // Dialog hiện lên: "Bạn đang tập dở buổi này (đã xong 1/3 hiệp). Tiếp tục?"
        expect(
          find.text('Bạn đang tập dở buổi này (đã xong 1/3 hiệp). Tiếp tục?'),
          findsOneWidget,
        );
        expect(find.text('Tiếp tục'), findsOneWidget);
        expect(find.text('Tập lại từ đầu'), findsOneWidget);

        // Bấm "Tiếp tục"
        await tester.tap(find.text('Tiếp tục'));
        await tester.pumpAndSettle();

        // Vào màn đang tập
        expect(find.byType(WorkoutActiveScreen), findsOneWidget);

        // Kiểm tra state đã khôi phục đúng bài/hiệp
        final restored = harness.container.read(activeWorkoutProvider)!;
        expect(restored.clientId, origClientId);
        expect(restored.startedAt.isAtSameMomentAs(origStartedAt), isTrue);
        expect(restored.sets, hasLength(1));
        expect(restored.sets.first.reps, 10);
        expect(restored.setNumber, 2);
        expect(restored.exerciseIndex, 0);
        expect(restored.currentItem?.exerciseId, squatId);
      },
    );

    testWidgets(
      '"Tập lại từ đầu" xoá nháp và bắt đầu buổi tập mới từ hiệp 1',
      (tester) async {
        final harness = WorkoutHarness(plan: testPlan, draftRepo: draftRepo);
        final session = testPlan.sessions.first;
        const origClientId = 'client-restart-test-12345';

        final sState = createIncompleteState(
          session: session,
          clientId: origClientId,
          setsLogged: 1,
        );

        await draftRepo.saveDraft(
          WorkoutDraft(
            clientId: sState.clientId,
            sessionId: session.id,
            stateJson: WorkoutDraft.encodeStateJson(sState),
            updatedAt: harness.clock.now.subtract(const Duration(minutes: 10)),
            status: 'active',
          ),
        );

        await harness.pump(tester, '/workout/${session.id}');

        expect(find.textContaining('Bạn đang tập dở buổi này'), findsOneWidget);

        // Bấm "Tập lại từ đầu"
        await tester.tap(find.text('Tập lại từ đầu'));
        await tester.pumpAndSettle();

        // Nháp cũ bị xóa khỏi repo
        expect(await draftRepo.getActiveDraft(), isNull);
        expect(await draftRepo.getDraft(origClientId), isNull);

        // Vào màn đang tập từ hiệp 1, không có hiệp nào đã lưu
        expect(find.byType(WorkoutActiveScreen), findsOneWidget);
        final fresh = harness.container.read(activeWorkoutProvider)!;
        expect(fresh.clientId, isNot(origClientId));
        expect(fresh.sets, isEmpty);
        expect(fresh.setNumber, 1);
        expect(fresh.exerciseIndex, 0);
      },
    );

    testWidgets(
      'Nháp hết hạn (> 12h) → không hỏi dialog',
      (tester) async {
        final harness = WorkoutHarness(plan: testPlan, draftRepo: draftRepo);
        final session = testPlan.sessions.first;

        final sState = createIncompleteState(
          session: session,
          clientId: 'client-expired-999',
          setsLogged: 1,
        );

        await draftRepo.saveDraft(
          WorkoutDraft(
            clientId: sState.clientId,
            sessionId: session.id,
            stateJson: WorkoutDraft.encodeStateJson(sState),
            updatedAt: harness.clock.now.subtract(const Duration(hours: 13)),
            status: 'active',
          ),
        );

        await harness.pump(tester, '/workout/${session.id}');

        // Không hiện dialog
        expect(find.textContaining('Bạn đang tập dở buổi này'), findsNothing);
        // Ở màn bắt đầu
        expect(find.byType(WorkoutStartScreen), findsOneWidget);
        expect(find.text('Bắt đầu'), findsOneWidget);
      },
    );

    testWidgets(
      'Nháp của buổi KHÁC: không hỏi, xoá nháp cũ khi bắt đầu buổi mới',
      (tester) async {
        final harness = WorkoutHarness(plan: testPlan, draftRepo: draftRepo);
        final session = testPlan.sessions.first;
        const otherClientId = 'client-other-session-888';

        final otherSession = SessionView(
          id: 'other-session-id-999',
          scheduledDate: '2026-10-04',
          scheduledTime: '07:00',
          title: 'Buổi hôm qua',
          durationMin: 20,
          items: const [ItemView(exerciseId: plankId, sets: 1, durationSec: 30)],
        );

        final sState = WorkoutSessionState(
          session: otherSession,
          items: [WorkoutPlanItem.from(otherSession.items[0], testExercises[1])],
          clientId: otherClientId,
          startedAt: harness.clock.now.subtract(const Duration(hours: 2)),
        );

        await draftRepo.saveDraft(
          WorkoutDraft(
            clientId: otherClientId,
            sessionId: otherSession.id,
            stateJson: WorkoutDraft.encodeStateJson(sState),
            updatedAt: harness.clock.now.subtract(const Duration(hours: 1)),
            status: 'active',
          ),
        );

        await harness.pump(tester, '/workout/${session.id}');

        // Không hỏi dialog
        expect(find.textContaining('Bạn đang tập dở buổi này'), findsNothing);
        expect(find.byType(WorkoutStartScreen), findsOneWidget);

        // Bấm "Bắt đầu" buổi mới
        await tester.tap(find.text('Bắt đầu'));
        await tester.pumpAndSettle();

        // Nháp cũ của buổi khác đã bị xóa
        expect(await draftRepo.getDraft(otherClientId), isNull);
        expect(find.byType(WorkoutActiveScreen), findsOneWidget);
      },
    );

    testWidgets(
      'activeWorkoutProvider đang giữ buổi chưa xong của CÙNG session.id → vào thẳng màn đang tập',
      (tester) async {
        final harness = WorkoutHarness(plan: testPlan, draftRepo: draftRepo);
        final session = testPlan.sessions.first;
        final sState = createIncompleteState(
          session: session,
          clientId: 'client-in-memory-777',
          setsLogged: 1,
        );

        // Thiết lập controller đang giữ state
        await harness.pump(tester, '/home');
        harness.container.read(activeWorkoutProvider.notifier).restore(sState);

        // Mở màn bắt đầu buổi cùng session.id
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: harness.container,
            child: MaterialApp.router(
              routerConfig: createAppRouter(
                initialLocation: '/workout/${session.id}',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Vào thẳng màn đang tập, không hiện dialog
        expect(find.textContaining('Bạn đang tập dở buổi này'), findsNothing);
        expect(find.byType(WorkoutActiveScreen), findsOneWidget);
        expect(
          harness.container.read(activeWorkoutProvider)!.clientId,
          'client-in-memory-777',
        );
      },
    );

    testWidgets(
      'Màn chính: có buổi đang tập dở đổi chữ thành "Tiếp tục buổi tập" và bấm thì xử lý đúng',
      (tester) async {
        final harness = WorkoutHarness(plan: testPlan, draftRepo: draftRepo);
        final session = testPlan.sessions.first;

        final sState = createIncompleteState(
          session: session,
          clientId: 'client-home-resume-555',
          setsLogged: 1,
        );

        await draftRepo.saveDraft(
          WorkoutDraft(
            clientId: sState.clientId,
            sessionId: session.id,
            stateJson: WorkoutDraft.encodeStateJson(sState),
            updatedAt: harness.clock.now.subtract(const Duration(minutes: 5)),
            status: 'active',
          ),
        );

        await harness.pump(tester, '/home');

        // Nút "Bắt đầu" đổi thành "Tiếp tục buổi tập"
        expect(find.text('Tiếp tục buổi tập'), findsOneWidget);
        expect(find.text('Bắt đầu'), findsNothing);

        // Bấm "Tiếp tục buổi tập"
        await tester.tap(find.text('Tiếp tục buổi tập'));
        await tester.pumpAndSettle();

        // Hiện dialog hỏi tiếp tục
        expect(find.textContaining('Bạn đang tập dở buổi này'), findsOneWidget);
        expect(find.text('Tiếp tục'), findsWidgets);

        // Bấm "Tiếp tục" trong dialog
        await tester.tap(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('Tiếp tục'),
          ),
        );
        await tester.pumpAndSettle();

        // Vào thẳng màn đang tập
        expect(find.byType(WorkoutActiveScreen), findsOneWidget);
        expect(
          harness.container.read(activeWorkoutProvider)!.clientId,
          'client-home-resume-555',
        );
      },
    );
  });
}
