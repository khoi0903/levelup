import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fitness_app/core/api/api_client.dart';
import 'package:fitness_app/core/api/api_exceptions.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/workout/data/camera/rep_counting_session.dart';
import 'package:fitness_app/features/workout/data/repositories/api_workout_repository.dart';
import 'package:fitness_app/features/workout/data/repositories/fake_workout_repository.dart';
import 'package:fitness_app/features/workout/domain/models/workout_models.dart';
import 'package:fitness_app/features/workout/domain/models/workout_session_state.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:fitness_app/features/workout/presentation/screens/camera_set_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'workout_test_helpers.dart';

// Tên trường chép đúng từ backend/src/main/java/vn/levelup/workouts/WorkoutRequest.java.
const backendRequestFields = {
  'clientId',
  'plannedSessionId',
  'startedAt',
  'endedAt',
  'variant',
  'rpe',
  'painAreas',
  'note',
  'sets',
};
const backendSetFields = {
  'exerciseId',
  'setIndex',
  'reps',
  'weightKg',
  'durationSec',
  'repSource',
  'repsDetected',
  'cvVersion',
  'avgConfidence',
  'formScore',
  'formIssues',
};
const backendFormIssueFields = {'repIndex', 'code', 'severity'};

WorkoutRequest fullRequest() => WorkoutRequest(
  clientId: 'AbCdEfGh12345678',
  plannedSessionId: sessionId,
  startedAt: DateTime.utc(2026, 10, 5, 11),
  endedAt: DateTime.utc(2026, 10, 5, 11, 12, 30),
  variant: 'normal',
  rpe: 7,
  painAreas: const [PainArea.lowerBack, PainArea.knee],
  note: '  hơi mỏi gối  ',
  sets: const [
    SetLog(
      exerciseId: squatId,
      setIndex: 1,
      reps: 12,
      repSource: RepSource.cameraCorrected,
      repsDetected: 11,
      cvVersion: 2,
      avgConfidence: 0.82,
      formScore: 75,
      formIssues: [
        FormIssueLog(repIndex: 3, code: 'shallow_depth', severity: 2),
      ],
    ),
    SetLog(exerciseId: gobletId, setIndex: 1, reps: 10, weightKg: 12.5),
    SetLog(exerciseId: plankId, setIndex: 1, durationSec: 45),
  ],
);

/// Adapter giả cho Dio: ghi lại body thật gửi đi, [failures] lần đầu ném lỗi mạng.
class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter({this.failures = 0});

  int failures;
  final List<String> paths = [];
  final List<Map<String, dynamic>> bodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add('${options.method} ${options.path}');
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    bodies.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    if (failures > 0) {
      failures--;
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    final response = {
      'workoutId': '6600000000000000000000aa',
      'localDate': '2026-10-05',
      'durationSec': 750,
      'countsForStreak': true,
      'duplicate': bodies.length > 1,
      'week': {
        'weekStart': '2026-10-05',
        'targetSessions': 3,
        'completedSessions': 1,
        'status': 'in_progress',
      },
      'personalRecords': [
        {
          'exerciseId': squatId,
          'nameVi': 'Squat',
          'metric': 'max_reps',
          'value': 12.0,
          'previous': null,
        },
      ],
      'newAchievements': [
        {
          'code': 'first_workout',
          'nameVi': 'Buổi đầu tiên',
          'descriptionVi': 'Hoàn thành buổi tập đầu tiên',
        },
      ],
    };
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

ApiClient clientWith(RecordingAdapter adapter) {
  final client = ApiClient(
    baseUrl: 'http://localhost:8081',
    tokenProvider: () async => 'dev-test',
  );
  client.dio.httpClientAdapter = adapter;
  return client;
}

void main() {
  group('WorkoutRequest.toJson khớp WorkoutRequest.java', () {
    test('chỉ dùng tên trường backend, đủ mọi trường đã điền', () {
      final json = fullRequest().toJson();
      expect(json.keys.toSet(), backendRequestFields);

      final sets = (json['sets'] as List).cast<Map<String, dynamic>>();
      for (final s in sets) {
        expect(
          backendSetFields.containsAll(s.keys),
          isTrue,
          reason: 'trường lạ trong set: ${s.keys}',
        );
      }
      expect(
        sets[0].keys.toSet(),
        backendSetFields.difference({'weightKg', 'durationSec'}),
      );
      final issue = (sets[0]['formIssues'] as List).single as Map;
      expect(issue.keys.toSet(), backendFormIssueFields);
      expect(issue, {'repIndex': 3, 'code': 'shallow_depth', 'severity': 2});
    });

    test('giá trị đúng định dạng backend', () {
      final json = fullRequest().toJson();
      expect(json['startedAt'], '2026-10-05T11:00:00.000Z');
      expect(json['endedAt'], '2026-10-05T11:12:30.000Z');
      expect(json['painAreas'], ['lower_back', 'knee']);
      expect(json['note'], 'hơi mỏi gối');
      final sets = (json['sets'] as List).cast<Map<String, dynamic>>();
      expect(sets[0]['repSource'], 'camera_corrected');
      expect(sets[0]['avgConfidence'], 0.82);
      expect(sets[1], {
        'exerciseId': gobletId,
        'setIndex': 1,
        'reps': 10,
        'weightKg': 12.5,
        'repSource': 'manual',
      });
      expect(sets[2], {
        'exerciseId': plankId,
        'setIndex': 1,
        'durationSec': 45,
        'repSource': 'manual',
      });
    });

    test('bỏ trường rỗng thay vì gửi null/[]/""', () {
      final json = WorkoutRequest(
        clientId: 'AbCdEfGh12345678',
        startedAt: DateTime.utc(2026, 10, 5, 11),
        endedAt: DateTime.utc(2026, 10, 5, 11, 1),
        variant: 'quick5',
        note: '   ',
        sets: const [SetLog(exerciseId: squatId, setIndex: 1, reps: 5)],
      ).toJson();
      expect(json.keys.toSet(), {
        'clientId',
        'startedAt',
        'endedAt',
        'variant',
        'sets',
      });
    });

    test('clientId sinh ra khớp regex backend', () {
      final re = RegExp(r'^[A-Za-z0-9_-]{8,64}$');
      for (var i = 0; i < 50; i++) {
        expect(re.hasMatch(generateClientId()), isTrue);
      }
    });
  });

  group('ApiWorkoutRepository', () {
    test('POST /workouts gửi đúng body JSON và đọc WorkoutResponse', () async {
      final adapter = RecordingAdapter();
      final repo = ApiWorkoutRepository(clientWith(adapter));
      final result = await repo.saveWorkout(fullRequest());

      expect(adapter.paths, ['POST /workouts']);
      expect(
        adapter.bodies.single,
        jsonDecode(jsonEncode(fullRequest().toJson())),
      );
      expect(result.workoutId, '6600000000000000000000aa');
      expect(result.countsForStreak, isTrue);
      expect(result.week!.completedSessions, 1);
      expect(result.personalRecords.single.metric, 'max_reps');
      expect(result.personalRecords.single.previous, isNull);
      expect(result.newAchievements.single.nameVi, 'Buổi đầu tiên');
    });

    test('lỗi mạng thành ApiException NETWORK_ERROR', () async {
      final repo = ApiWorkoutRepository(
        clientWith(RecordingAdapter(failures: 1)),
      );
      await expectLater(
        repo.saveWorkout(fullRequest()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.isNetworkError,
            'isNetworkError',
            isTrue,
          ),
        ),
      );
    });
  });

  group('WorkoutController.submit', () {
    late ProviderContainer container;
    late FakeClock clock;

    WorkoutSetup setup() => WorkoutSetup(
      session: planWith(const [
        ItemView(exerciseId: squatId, nameVi: 'Squat', sets: 1, reps: 10),
      ]).sessions.single,
      items: [
        WorkoutPlanItem.from(
          const ItemView(
            exerciseId: squatId,
            nameVi: 'Squat',
            sets: 1,
            reps: 10,
          ),
          testExercises.first,
        ),
      ],
    );

    ProviderContainer containerWith(List<Override> overrides) {
      clock = FakeClock();
      final c = ProviderContainer(
        overrides: [
          workoutClockProvider.overrideWithValue(clock.call),
          planRepositoryProvider.overrideWithValue(
            FakePlanRepository(planView: planWith(const [])),
          ),
          ...overrides,
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test(
      'gửi lại sau lỗi mạng dùng CÙNG clientId và giờ kết thúc (qua HTTP)',
      () async {
        final adapter = RecordingAdapter(failures: 1);
        container = containerWith([
          workoutRepositoryProvider.overrideWithValue(
            ApiWorkoutRepository(clientWith(adapter)),
          ),
        ]);
        final notifier = container.read(activeWorkoutProvider.notifier);
        notifier.start(setup());
        notifier.logSet(
          const SetLog(exerciseId: squatId, setIndex: 1, reps: 10),
        );
        clock.now = clock.now.add(const Duration(minutes: 6));

        expect(await notifier.submit(rpe: 7), isNull);
        final failed = container.read(activeWorkoutProvider)!;
        expect(failed.error!.isNetworkError, isTrue);
        expect(failed.result, isNull);

        // Người dùng chờ có mạng lại mới bấm thử: giờ kết thúc không đổi.
        clock.now = clock.now.add(const Duration(minutes: 3));
        final result = await notifier.submit(rpe: 8);
        expect(result, isNotNull);
        expect(container.read(activeWorkoutProvider)!.error, isNull);

        expect(adapter.bodies, hasLength(2));
        final first = adapter.bodies[0];
        final second = adapter.bodies[1];
        expect(second['clientId'], first['clientId']);
        expect(second['startedAt'], first['startedAt']);
        expect(second['endedAt'], first['endedAt']);
        expect(second['endedAt'], '2026-10-05T11:06:00.000Z');
        expect(second['plannedSessionId'], sessionId);
        expect(second['rpe'], 8);
      },
    );

    test('đã có kết quả thì không gửi lần nữa', () async {
      final repo = FakeWorkoutRepository(exercises: testExercises);
      container = containerWith([
        workoutRepositoryProvider.overrideWithValue(repo),
      ]);
      final notifier = container.read(activeWorkoutProvider.notifier);
      notifier.start(setup());
      notifier.logSet(const SetLog(exerciseId: squatId, setIndex: 1, reps: 10));
      final a = await notifier.submit();
      final b = await notifier.submit();
      expect(identical(a, b), isTrue);
      expect(repo.sentRequests, hasLength(1));
    });

    test('mỗi buổi mới có clientId mới', () {
      container = containerWith([
        workoutRepositoryProvider.overrideWithValue(
          FakeWorkoutRepository(exercises: testExercises),
        ),
      ]);
      final notifier = container.read(activeWorkoutProvider.notifier);
      notifier.start(setup());
      final first = container.read(activeWorkoutProvider)!.clientId;
      notifier.clear();
      notifier.start(setup());
      expect(container.read(activeWorkoutProvider)!.clientId, isNot(first));
    });

    test('id buổi không phải ObjectId thì không gửi plannedSessionId', () {
      final s = WorkoutSessionState(
        session: const SessionView(
          id: 's1',
          scheduledDate: '2026-10-05',
          scheduledTime: '18:00',
          title: 'Demo',
          durationMin: 10,
          variant: 'weird',
          items: [],
        ),
        items: const [],
        clientId: 'AbCdEfGh12345678',
        startedAt: DateTime.utc(2026),
      );
      expect(s.plannedSessionId, isNull);
      expect(s.variant, 'normal');
    });

    test('tập thêm buổi đã hoàn thành thì không gắn plannedSessionId', () {
      SessionView session(String status) => SessionView(
        id: sessionId,
        scheduledDate: '2026-10-05',
        scheduledTime: '18:00',
        title: 'Buổi 1',
        durationMin: 10,
        variant: 'normal',
        status: status,
        items: const [],
      );
      WorkoutSessionState state(String status) => WorkoutSessionState(
        session: session(status),
        items: const [],
        clientId: 'AbCdEfGh12345678',
        startedAt: DateTime.utc(2026),
      );
      expect(state('planned').plannedSessionId, sessionId);
      expect(state('completed').plannedSessionId, isNull);
    });
  });

  group('buildCameraSetLog', () {
    final item = WorkoutPlanItem.from(
      const ItemView(exerciseId: squatId, nameVi: 'Squat', sets: 3, reps: 10),
      testExercises.first,
    );
    const snapshot = RepSnapshot(
      repCount: 8,
      averageConfidence: 0.8234,
      formScore: 75,
      issues: [FormIssueLog(repIndex: 3, code: 'shallow_depth', severity: 2)],
      status: RepCountingStatus.stopped,
    );

    test('giữ nguyên số camera đếm thì repSource = camera', () {
      final set = buildCameraSetLog(
        item: item,
        camera: squatCamera,
        snapshot: snapshot,
        confirmedReps: 8,
      );
      final json = set.toJson();
      expect(json['repSource'], 'camera');
      expect(json['reps'], 8);
      expect(json['repsDetected'], 8);
      expect(json['cvVersion'], 2);
      expect(json['avgConfidence'], 0.823);
      expect(json['formScore'], 75);
      expect(json['formIssues'], [
        {'repIndex': 3, 'code': 'shallow_depth', 'severity': 2},
      ]);
      expect(json.containsKey('weightKg'), isFalse);
    });

    test(
      'sửa số lần thì repSource = camera_corrected, vẫn giữ repsDetected',
      () {
        final json = buildCameraSetLog(
          item: item,
          camera: squatCamera,
          snapshot: snapshot,
          confirmedReps: 10,
        ).toJson();
        expect(json['repSource'], 'camera_corrected');
        expect(json['reps'], 10);
        expect(json['repsDetected'], 8);
        expect(json['cvVersion'], 2);
        expect(json['formScore'], 75);
      },
    );
  });

  group('buildCameraSetLog giữ tư thế (plank)', () {
    final item = WorkoutPlanItem.from(
      const ItemView(
        exerciseId: plankId,
        nameVi: 'Plank',
        sets: 3,
        durationSec: 30,
      ),
      testExercises.firstWhere((e) => e.id == plankId),
    );
    const snapshot = RepSnapshot(
      isHold: true,
      holdDuration: Duration(seconds: 42, milliseconds: 700),
      averageConfidence: 0.9,
      formScore: 90,
      status: RepCountingStatus.stopped,
    );

    test('lưu durationSec đo được, không có reps, repSource camera', () {
      final json = buildCameraSetLog(
        item: item,
        camera: squatCamera,
        snapshot: snapshot,
        confirmedReps: 0,
      ).toJson();
      expect(json['durationSec'], 42);
      expect(json.containsKey('reps'), isFalse);
      expect(json.containsKey('repsDetected'), isFalse);
      expect(json['repSource'], 'camera');
      expect(json['formScore'], 90);
    });

    test('sửa thời gian thì camera_corrected, giới hạn 7200 giây', () {
      final edited = buildCameraSetLog(
        item: item,
        camera: squatCamera,
        snapshot: snapshot,
        confirmedReps: 0,
        confirmedSeconds: 45,
      ).toJson();
      expect(edited['durationSec'], 45);
      expect(edited['repSource'], 'camera_corrected');
      final capped = buildCameraSetLog(
        item: item,
        camera: squatCamera,
        snapshot: snapshot,
        confirmedReps: 0,
        confirmedSeconds: 9000,
      ).toJson();
      expect(capped['durationSec'], 7200);
    });
  });

  test('hiệp sau giữ số lần đã chỉnh của cùng bài (không về mặc định 10)', () {
    final s = WorkoutSessionState(
      session: const SessionView(
        id: sessionId,
        scheduledDate: '2026-10-05',
        scheduledTime: '18:00',
        title: 'Buổi 1',
        durationMin: 10,
        variant: 'normal',
        items: [],
      ),
      items: const [],
      clientId: 'AbCdEfGh12345678',
      startedAt: DateTime.utc(2026),
      sets: const [
        SetLog(exerciseId: squatId, setIndex: 1, reps: 12, repSource: RepSource.manual),
        SetLog(exerciseId: plankId, setIndex: 1, durationSec: 30, repSource: RepSource.manual),
      ],
    );
    expect(s.lastRepsFor(squatId), 12);
    expect(s.lastRepsFor(plankId), isNull);
    expect(s.lastRepsFor(gobletId), isNull);
  });

  test('lỗi camera hiện câu tiếng Việt, không lộ chuỗi kỹ thuật', () {
    expect(cameraErrorMessage('CameraException(CameraAccessDenied, denied)'),
        contains('Chưa có quyền camera'));
    expect(cameraErrorMessage('StateError: No front camera available'),
        contains('camera trước'));
    final generic = cameraErrorMessage('PlatformException(error, Something broke, null, null)');
    expect(generic, contains('Camera đang gặp sự cố'));
    expect(generic.contains('PlatformException'), isFalse);
  });
}
