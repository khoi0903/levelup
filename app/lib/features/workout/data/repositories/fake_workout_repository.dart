import '../../../../core/api/api_exceptions.dart';
import '../../../onboarding/data/repositories/fake_plan_repository.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../domain/models/exercise_alternative.dart';
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
    this.planRepo,
    this.fakeAlternatives,
  }) : exercises = exercises ?? defaultExercises;

  final List<ExerciseResponse> exercises;
  final WorkoutResult? result;
  PlanView? plan;
  FakePlanRepository? planRepo;
  List<ExerciseAlternative>? fakeAlternatives;
  ApiException? swapFailure;
  ApiException? alternativesFailure;

  /// Số lần POST /workouts đầu tiên ném [failure] (mô phỏng mất mạng).
  int failuresBeforeSuccess;
  final ApiException failure;

  /// Mọi request đã gửi, kể cả lần lỗi.
  final List<WorkoutRequest> sentRequests = [];
  final List<String> quick5Sessions = [];
  final List<Map<String, dynamic>> sentSwaps = [];
  final List<Map<String, dynamic>> sentAlternativeQueries = [];

  /// Số lần GET /exercises (màn tập thêm chỉ được tải một lần).
  int getExercisesCalls = 0;

  @override
  Future<List<ExerciseResponse>> getExercises() async {
    getExercisesCalls++;
    return exercises;
  }

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

  @override
  Future<List<ExerciseAlternative>> getAlternatives({
    required String sessionId,
    required String exerciseId,
  }) async {
    sentAlternativeQueries.add({
      'sessionId': sessionId,
      'exerciseId': exerciseId,
    });
    if (alternativesFailure != null) {
      throw alternativesFailure!;
    }
    if (fakeAlternatives != null) {
      return fakeAlternatives!;
    }
    return exercises
        .where((e) => e.id != exerciseId)
        .take(6)
        .map(
          (e) => ExerciseAlternative(
            exerciseId: e.id,
            nameVi: e.nameVi,
            slug: e.slug,
            thumbnailUrl: e.thumbnailUrl,
            primaryMuscle: e.primaryMuscle,
            tracking: e.tracking,
            cameraSupported: e.camera != null,
            reason: 'Cùng nhóm cơ · Không cần dụng cụ',
          ),
        )
        .toList();
  }

  @override
  Future<PlanView> swapExercise({
    required String sessionId,
    required String fromExerciseId,
    required String toExerciseId,
    required bool remember,
  }) async {
    sentSwaps.add({
      'sessionId': sessionId,
      'fromExerciseId': fromExerciseId,
      'toExerciseId': toExerciseId,
      'remember': remember,
    });
    if (swapFailure != null) {
      throw swapFailure!;
    }
    final toEx = exercises.firstWhere(
      (e) => e.id == toExerciseId,
      orElse: () => ExerciseResponse(
        id: toExerciseId,
        slug: toExerciseId,
        nameVi: 'Bài mới',
      ),
    );
    final base = plan ?? await FakePlanRepository().getCurrentPlan();
    final updatedSessions = base.sessions.map((s) {
      if (s.id == sessionId) {
        final updatedItems = s.items.map((i) {
          if (i.exerciseId == fromExerciseId) {
            return ItemView(
              exerciseId: toExerciseId,
              nameVi: toEx.nameVi,
              sets: i.sets,
              reps: toEx.tracking == 'duration' ? null : (i.reps ?? 10),
              durationSec: toEx.tracking == 'duration'
                  ? (i.durationSec ?? 30)
                  : null,
              restSec: i.restSec,
            );
          }
          return i;
        }).toList();
        return SessionView(
          id: s.id,
          scheduledDate: s.scheduledDate,
          scheduledTime: s.scheduledTime,
          title: s.title,
          durationMin: s.durationMin,
          variant: s.variant,
          status: s.status,
          items: updatedItems,
          adjustedReason: s.adjustedReason,
        );
      }
      return s;
    }).toList();
    final newPlan = PlanView(
      id: base.id,
      weekStart: base.weekStart,
      status: base.status,
      targetSessions: base.targetSessions,
      sessions: updatedSessions,
      injuryNote: base.injuryNote,
    );
    plan = newPlan;
    planRepo?.planView = newPlan;
    return newPlan;
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
