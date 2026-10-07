import '../../../onboarding/domain/models/plan_models.dart';
import '../models/exercise_alternative.dart';
import '../models/exercise_response.dart';
import '../models/workout_models.dart';

abstract class WorkoutRepository {
  /// GET /exercises: thư viện bài tập đã lọc cho người dùng, kèm cấu hình camera.
  Future<List<ExerciseResponse>> getExercises();

  /// POST /workouts. Gửi lại cùng clientId thì backend trả kết quả cũ (duplicate).
  Future<WorkoutResult> saveWorkout(WorkoutRequest request);

  /// PATCH /plans/sessions/{id} {action: quick5}: đổi buổi sang bản 5 phút.
  Future<PlanView> makeQuick5(String sessionId);

  /// GET /plans/sessions/{sessionId}/alternatives?exerciseId={exerciseId}
  Future<List<ExerciseAlternative>> getAlternatives({
    required String sessionId,
    required String exerciseId,
  });

  /// POST /plans/sessions/{sessionId}/swap
  Future<PlanView> swapExercise({
    required String sessionId,
    required String fromExerciseId,
    required String toExerciseId,
    required bool remember,
  });
}

