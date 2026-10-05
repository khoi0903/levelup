import 'package:fitness_app/features/home/presentation/controllers/home_controller.dart';
import 'package:fitness_app/features/workout/data/repositories/fake_workout_repository.dart';
import 'package:fitness_app/features/workout/data/repositories/memory_workout_draft_repository.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/workout/domain/models/workout_draft.dart';
import 'package:fitness_app/features/workout/domain/models/workout_models.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test_helpers.dart';

void main() {
  group('Workout Draft (Offline Drift & Memory Repo)', () {
    late MemoryWorkoutDraftRepository draftRepo;
    late FakeWorkoutRepository workoutRepo;
    late FakeClock clock;
    late ProviderContainer container;

    setUp(() {
      draftRepo = MemoryWorkoutDraftRepository();
      workoutRepo = FakeWorkoutRepository();
      clock = FakeClock();
      container = ProviderContainer(
        overrides: [
          workoutDraftRepositoryProvider.overrideWithValue(draftRepo),
          workoutRepositoryProvider.overrideWithValue(workoutRepo),
          workoutClockProvider.overrideWithValue(clock.call),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    WorkoutSetup makeSetup() {
      final plan = planWith(const [
        ItemView(exerciseId: squatId, sets: 2, reps: 10, restSec: 45),
        ItemView(exerciseId: plankId, sets: 1, durationSec: 30),
      ]);
      return WorkoutSetup(
        session: plan.sessions.first,
        items: [
          WorkoutPlanItem.from(plan.sessions.first.items[0], testExercises[0]),
          WorkoutPlanItem.from(plan.sessions.first.items[1], testExercises[1]),
        ],
      );
    }

    test('Lưu draft sau mỗi set ghi xong và khi chuyển bài', () async {
      final controller = container.read(activeWorkoutProvider.notifier);
      final setup = makeSetup();
      controller.start(setup);

      // Ban đầu chưa có set nào ghi
      var active = await draftRepo.getActiveDraft();
      expect(active, isNull);

      // 1. Ghi set 1 của squat -> draft được lưu
      controller.logSet(
        const SetLog(exerciseId: squatId, setIndex: 1, reps: 10),
      );
      await Future<void>.delayed(Duration.zero);

      active = await draftRepo.getActiveDraft();
      expect(active, isNotNull);
      expect(active!.status, 'active');
      expect(active.sessionId, setup.session.id);
      expect(active.sessionState.sets, hasLength(1));
      expect(active.sessionState.setNumber, 2);

      // 2. Chuyển bài (skipExercise) -> draft cập nhật
      controller.skipExercise();
      await Future<void>.delayed(Duration.zero);

      active = await draftRepo.getActiveDraft();
      expect(active, isNotNull);
      expect(active!.sessionState.exerciseIndex, 1);
      expect(active.sessionState.setNumber, 1);
    });

    test('Xóa draft khi POST /workouts thành công', () async {
      final controller = container.read(activeWorkoutProvider.notifier);
      final setup = makeSetup();
      controller.start(setup);

      controller.logSet(
        const SetLog(exerciseId: squatId, setIndex: 1, reps: 10),
      );
      await Future<void>.delayed(Duration.zero);

      final clientId = container.read(activeWorkoutProvider)!.clientId;
      expect(await draftRepo.getDraft(clientId), isNotNull);

      // Submit thành công
      final result = await controller.submit(
        rpe: 8,
        painAreas: [PainArea.knee],
        note: 'Tốt',
      );
      expect(result, isNotNull);

      // Draft đã bị xóa
      expect(await draftRepo.getDraft(clientId), isNull);
      expect(await draftRepo.getActiveDraft(), isNull);
    });

    test(
      'Gửi lỗi mạng -> chuyển draft sang pending_submit, giữ rpe, painAreas, note',
      () async {
        workoutRepo.failuresBeforeSuccess = 1;

        final controller = container.read(activeWorkoutProvider.notifier);
        final setup = makeSetup();
        controller.start(setup);

        controller.logSet(
          const SetLog(exerciseId: squatId, setIndex: 1, reps: 10),
        );
        await Future<void>.delayed(Duration.zero);

        final clientId = container.read(activeWorkoutProvider)!.clientId;

        // Submit bị lỗi mạng
        final result = await controller.submit(
          rpe: 9,
          painAreas: [PainArea.lowerBack],
          note: 'Hơi mỏi lưng',
        );
        expect(result, isNull);

        final draft = await draftRepo.getDraft(clientId);
        expect(draft, isNotNull);
        expect(draft!.status, 'pending_submit');
        expect(draft.isPendingSubmit, isTrue);
        expect(draft.rpe, 9);
        expect(draft.painAreas, [PainArea.lowerBack]);
        expect(draft.note, 'Hơi mỏi lưng');

        // toWorkoutRequest giữ nguyên thông tin để gửi lại
        final req = draft.toWorkoutRequest();
        expect(req.clientId, clientId);
        expect(req.rpe, 9);
        expect(req.painAreas, [PainArea.lowerBack]);
        expect(req.note, 'Hơi mỏi lưng');
      },
    );

    test(
      'Gửi lại pending_submit thành công -> dùng cùng clientId và xóa draft',
      () async {
        final setup = makeSetup();
        final sState = WorkoutSessionState(
          session: setup.session,
          items: setup.items,
          clientId: 'client-offline-123456789012',
          startedAt: DateTime.utc(2026, 10, 5, 10, 0),
          endedAt: DateTime.utc(2026, 10, 5, 10, 30),
          sets: const [
            SetLog(exerciseId: squatId, setIndex: 1, reps: 10),
          ],
        );

        final draft = WorkoutDraft(
          clientId: sState.clientId,
          sessionId: sState.session.id,
          stateJson: WorkoutDraft.encodeStateJson(
            sState,
            rpe: 7,
            note: 'Tập offline',
          ),
          updatedAt: clock.now,
          status: 'pending_submit',
        );
        await draftRepo.saveDraft(draft);

        expect(await draftRepo.getPendingSubmitDrafts(), hasLength(1));

        // Sync pending drafts khi có mạng lại
        var successCalled = false;
        final synced = await syncPendingWorkoutDrafts(
          draftRepo: draftRepo,
          workoutRepo: workoutRepo,
          now: clock.now,
          onSuccess: () => successCalled = true,
        );

        expect(synced, isTrue);
        expect(successCalled, isTrue);
        expect(workoutRepo.sentRequests, hasLength(1));
        expect(workoutRepo.sentRequests.first.clientId, 'client-offline-123456789012');
        expect(workoutRepo.sentRequests.first.rpe, 7);
        expect(workoutRepo.sentRequests.first.note, 'Tập offline');

        // Draft bị xóa khỏi local sau khi gửi thành công
        expect(await draftRepo.getDraft('client-offline-123456789012'), isNull);
        expect(await draftRepo.getPendingSubmitDrafts(), isEmpty);
      },
    );

    test('Quá 12 giờ tự xóa draft', () async {
      final setup = makeSetup();
      final sState = WorkoutSessionState(
        session: setup.session,
        items: setup.items,
        clientId: 'expired-client-1234567890',
        startedAt: clock.now.subtract(const Duration(hours: 13)),
      );

      final expiredDraft = WorkoutDraft(
        clientId: sState.clientId,
        sessionId: sState.session.id,
        stateJson: WorkoutDraft.encodeStateJson(sState),
        updatedAt: clock.now.subtract(const Duration(hours: 13)),
        status: 'active',
      );
      await draftRepo.saveDraft(expiredDraft);

      expect(expiredDraft.isExpired(clock.now), isTrue);

      final deletedCount = await draftRepo.deleteExpiredDrafts(clock.now);
      expect(deletedCount, 1);
      expect(await draftRepo.getActiveDraft(), isNull);
    });

    test('Bỏ buổi tập (discard) xóa draft khỏi bộ nhớ và database', () async {
      final controller = container.read(activeWorkoutProvider.notifier);
      final setup = makeSetup();
      controller.start(setup);

      controller.logSet(
        const SetLog(exerciseId: squatId, setIndex: 1, reps: 10),
      );
      await Future<void>.delayed(Duration.zero);

      final clientId = container.read(activeWorkoutProvider)!.clientId;
      expect(await draftRepo.getDraft(clientId), isNotNull);

      controller.discard();
      await Future<void>.delayed(Duration.zero);

      expect(container.read(activeWorkoutProvider), isNull);
      expect(await draftRepo.getDraft(clientId), isNull);
    });
  });
}
