import 'package:fitness_app/core/voice/voice_coach.dart';
import 'package:fitness_app/core/voice/voice_provider.dart';
import 'package:fitness_app/features/workout/data/camera/auto_camera_setting.dart';
import 'package:fitness_app/features/workout/data/camera/camera_setup_skip.dart';

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:fitness_app/app/router.dart';
import 'package:fitness_app/features/onboarding/data/repositories/fake_plan_repository.dart';
import 'package:fitness_app/features/onboarding/domain/models/plan_models.dart';
import 'package:fitness_app/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:fitness_app/features/users/data/repositories/fake_user_repository.dart';
import 'package:fitness_app/features/users/domain/models/me_response.dart';
import 'package:fitness_app/features/users/presentation/controllers/user_controller.dart';
import 'package:fitness_app/features/workout/data/camera/camera_permission.dart';
import 'package:fitness_app/features/workout/data/camera/rep_counting_session.dart';
import 'package:fitness_app/features/workout/data/repositories/fake_workout_repository.dart';
import 'package:fitness_app/features/coach/data/repositories/fake_coach_repository.dart';
import 'package:fitness_app/features/coach/presentation/controllers/coach_controller.dart';
import 'package:fitness_app/features/workout/data/repositories/memory_workout_draft_repository.dart';
import 'package:fitness_app/features/workout/domain/repositories/workout_draft_repository.dart';
import 'package:fitness_app/features/workout/domain/models/exercise_response.dart';
import 'package:fitness_app/features/workout/presentation/controllers/workout_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const squatId = '64b000000000000000000002';
const plankId = '64b000000000000000000003';
const gobletId = '64b000000000000000000004';
const sessionId = '650000000000000000000001';

const squatCamera = ExerciseCamera(
  version: 2,
  cameraPosition: 'side',
  config: {
    'joints': ['hip', 'knee', 'ankle'],
    'downBelow': 95,
    'upAbove': 160,
    'minConfidence': 0.6,
    'minRepMs': 600,
    'setupTipVi': 'Mặc quần gọn để thấy rõ gối.',
  },
);

const testExercises = [
  ExerciseResponse(
    id: squatId,
    slug: 'squat',
    nameVi: 'Squat',
    instructions: 'Hạ hông như ngồi ghế.',
    cues: ['Giữ lưng thẳng'],
    tracking: 'reps',
    camera: squatCamera,
  ),
  ExerciseResponse(
    id: plankId,
    slug: 'plank',
    nameVi: 'Plank',
    tracking: 'duration',
  ),
  ExerciseResponse(
    id: gobletId,
    slug: 'goblet-squat',
    nameVi: 'Squat ôm tạ',
    tracking: 'reps_weight',
  ),
];

PlanView planWith(
  List<ItemView> items, {
  String? variant,
  String status = 'planned',
}) => PlanView(
  id: 'plan',
  weekStart: '2026-10-05',
  status: 'active',
  targetSessions: 3,
  sessions: [
    SessionView(
      id: sessionId,
      scheduledDate: '2026-10-05',
      scheduledTime: '18:00',
      title: 'Toàn thân',
      durationMin: 12,
      status: status,
      variant: variant ?? 'normal',
      items: items,
    ),
  ],
);

/// Đồng hồ giả: mỗi lần đọc trả về [now], test tự đẩy thời gian.
class FakeClock {
  DateTime now = DateTime.utc(2026, 10, 5, 11, 0, 0);
  DateTime call() => now;
}

class FakePermissionGate implements CameraPermissionGate {
  FakePermissionGate([this.result = CameraPermissionResult.granted]);
  CameraPermissionResult result;
  int opened = 0;

  @override
  Future<void> openSettings() async => opened++;

  @override
  Future<CameraPermissionResult> request() async => result;
}

class FakeRepSession implements RepCountingSession {
  FakeRepSession(this.onStartSnapshot);

  final RepSnapshot onStartSnapshot;
  final _controller = StreamController<RepSnapshot>.broadcast();
  RepSnapshot _latest = const RepSnapshot();
  int starts = 0;
  int stops = 0;

  void emit(RepSnapshot s) {
    _latest = s;
    if (!_controller.isClosed) _controller.add(s);
  }

  @override
  CameraController? get cameraController => null;

  @override
  RepSnapshot get latest => _latest;

  @override
  Stream<RepSnapshot> get results => _controller.stream;

  @override
  Future<void> pause() async => emit(
    RepSnapshot(
      repCount: _latest.repCount,
      issues: _latest.issues,
      formScore: _latest.formScore,
      averageConfidence: _latest.averageConfidence,
      status: RepCountingStatus.paused,
    ),
  );

  @override
  Future<void> start() async {
    starts++;
    emit(onStartSnapshot);
  }

  @override
  Future<void> stop() async {
    stops++;
    _latest = RepSnapshot(
      repCount: _latest.repCount,
      issues: _latest.issues,
      formScore: _latest.formScore,
      averageConfidence: _latest.averageConfidence,
      status: RepCountingStatus.stopped,
    );
    await _controller.close();
  }
}

class FakeRepSessionFactory implements RepSessionFactory {
  FakeRepSessionFactory(this.snapshot);

  final RepSnapshot snapshot;
  final List<FakeRepSession> created = [];

  @override
  RepCountingSession create(ExerciseCamera camera) {
    final s = FakeRepSession(snapshot);
    created.add(s);
    return s;
  }

  @override
  bool supports(ExerciseCamera? camera) => camera?.config != null;
}

class NoCameraFactory implements RepSessionFactory {
  @override
  RepCountingSession create(ExerciseCamera camera) =>
      throw UnsupportedError('no camera');

  @override
  bool supports(ExerciseCamera? camera) => false;
}

class WorkoutHarness {
  WorkoutHarness({
    required PlanView plan,
    FakeWorkoutRepository? repo,
    WorkoutDraftRepository? draftRepo,
    RepSessionFactory? factory,
    FakePermissionGate? permission,
    CameraSetupSkip? setupSkip,
    this.autoCamera = false,
  }) : planRepo = FakePlanRepository(planView: plan),
       repo = repo ?? FakeWorkoutRepository(exercises: testExercises),
       draftRepo = draftRepo ?? MemoryWorkoutDraftRepository(),
       factory = factory ?? NoCameraFactory(),
       permission = permission ?? FakePermissionGate(),
       setupSkip = setupSkip ?? MemoryCameraSetupSkip() {
    this.repo.planRepo ??= planRepo;
    this.repo.plan ??= plan;
  }

  final FakePlanRepository planRepo;
  final FakeWorkoutRepository repo;
  final WorkoutDraftRepository draftRepo;
  final RepSessionFactory factory;
  final FakePermissionGate permission;
  final CameraSetupSkip setupSkip;

  /// "Tự mở camera khi bắt đầu hiệp" (app mặc định bật). Test cũ đi luồng bấm tay nên mặc định tắt ở đây.
  final bool autoCamera;

  /// Ghi lại câu giọng đọc đã "nói" để test kiểm tra.
  final voice = FakeVoiceCoach();
  final clock = FakeClock();
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, String location) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    container = ProviderContainer(
      overrides: [
        planRepositoryProvider.overrideWithValue(planRepo),
        workoutRepositoryProvider.overrideWithValue(repo),
        workoutDraftRepositoryProvider.overrideWithValue(draftRepo),
        repSessionFactoryProvider.overrideWithValue(factory),
        cameraPermissionProvider.overrideWithValue(permission),
        cameraSetupSkipProvider.overrideWithValue(setupSkip),
        autoCameraProvider.overrideWith((ref) => FixedAutoCamera(autoCamera)),
        // Giọng đọc giả: test không có engine TTS thật (không chờ "nói xong", không gọi plugin)
        voiceCoachProvider.overrideWithValue(voice),
        workoutClockProvider.overrideWithValue(clock.call),
        // /me.localDate (ngày theo máy chủ) khớp đồng hồ giả
        userRepositoryProvider.overrideWithValue(
          FakeUserRepository(
            meResponse: MeResponse(
              id: 'u-test',
              displayName: 'Test',
              localDate: localDateString(clock.now),
            ),
          ),
        ),
        coachRepositoryProvider.overrideWithValue(
          FakeCoachRepository(initialMessages: const []),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: createAppRouter(initialLocation: location),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Giá trị cố định cho test (không đọc SharedPreferences).
class FixedAutoCamera extends AutoCameraNotifier {
  FixedAutoCamera(bool value) {
    state = value;
  }
}
