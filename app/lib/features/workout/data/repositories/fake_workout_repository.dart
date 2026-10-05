import '../../../../core/api/api_exceptions.dart';
import '../../../onboarding/data/repositories/fake_plan_repository.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../domain/models/exercise_response.dart';
import '../../domain/models/workout_models.dart';
import '../../domain/repositories/workout_repository.dart';

/// Repository giả cho test và chạy app không cần backend.
class FakeWorkoutRepository implements WorkoutRepository {
  FakeWorkoutRepository({
    List<ExerciseResponse>? exercises,
    this.result,
    this.failuresBeforeSuccess = 0,
    this.failure = const ApiException(code: 'NETWORK_ERROR'),
    this.plan,
  }) : exercises = exercises ?? defaultExercises;

  final List<ExerciseResponse> exercises;
  final WorkoutResult? result;
  final PlanView? plan;

  /// Số lần POST /workouts đầu tiên ném [failure] (mô phỏng mất mạng).
  int failuresBeforeSuccess;
  final ApiException failure;

  /// Mọi request đã gửi, kể cả lần lỗi.
  final List<WorkoutRequest> sentRequests = [];
  final List<String> quick5Sessions = [];

  @override
  Future<List<ExerciseResponse>> getExercises() async => exercises;

  @override
  Future<WorkoutResult> saveWorkout(WorkoutRequest request) async {
    sentRequests.add(request);
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw failure;
    }
    final duration = request.endedAt.difference(request.startedAt).inSeconds;
    return result ??
        WorkoutResult(
          workoutId: 'fake-workout-${sentRequests.length}',
          localDate: '2026-10-05',
          durationSec: duration,
          countsForStreak: duration >= 300,
          duplicate:
              sentRequests.where((r) => r.clientId == request.clientId).length >
              1,
          week: const WeekProgress(
            weekStart: '2026-10-05',
            targetSessions: 3,
            completedSessions: 1,
            status: 'in_progress',
          ),
          kcalBurned: duration > 0 ? ((duration / 60) * 6).round() : 120,
        );
  }

  @override
  Future<PlanView> makeQuick5(String sessionId) async {
    quick5Sessions.add(sessionId);
    final base = plan ?? await FakePlanRepository().getCurrentPlan();
    return PlanView(
      id: base.id,
      weekStart: base.weekStart,
      status: base.status,
      targetSessions: base.targetSessions,
      sessions: base.sessions
          .map(
            (s) => s.id == sessionId
                ? SessionView(
                    id: s.id,
                    scheduledDate: s.scheduledDate,
                    scheduledTime: s.scheduledTime,
                    title: s.title,
                    durationMin: 5,
                    variant: 'quick5',
                    status: s.status,
                    items: s.items
                        .map(
                          (i) => ItemView(
                            exerciseId: i.exerciseId,
                            nameVi: i.nameVi,
                            sets: 1,
                            reps: i.reps,
                            durationSec: i.durationSec,
                            restSec: i.restSec,
                          ),
                        )
                        .toList(),
                  )
                : s,
          )
          .toList(),
    );
  }

  /// Khớp id bài trong FakePlanRepository.
  static const List<ExerciseResponse> defaultExercises = [
    ExerciseResponse(
      id: 'ex1',
      slug: 'jumping-jack',
      nameVi: 'Bật nhảy tại chỗ',
      instructions: 'Bật nhảy, dang tay chân rồi khép lại.',
      cues: ['Tiếp đất nhẹ bằng mũi chân'],
      tracking: 'reps',
    ),
    ExerciseResponse(
      id: 'ex2',
      slug: 'bodyweight-squat',
      nameVi: 'Squat không tạ',
      instructions: 'Hạ hông như ngồi xuống ghế rồi đứng lên.',
      cues: ['Giữ lưng thẳng', 'Gối hướng cùng chiều mũi chân'],
      tracking: 'reps',
      camera: ExerciseCamera(
        version: 1,
        cameraPosition: 'side',
        config: {
          'joints': ['hip', 'knee', 'ankle'],
          'downBelow': 95,
          'upAbove': 160,
          'minConfidence': 0.6,
          'minRepMs': 600,
        },
      ),
    ),
    ExerciseResponse(
      id: 'ex3',
      slug: 'plank',
      nameVi: 'Plank',
      instructions: 'Chống khuỷu tay, giữ thân thẳng.',
      cues: ['Siết bụng, không võng lưng'],
      tracking: 'duration',
    ),
  ];
}
