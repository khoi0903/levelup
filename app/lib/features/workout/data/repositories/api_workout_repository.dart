import 'package:dio/dio.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../domain/models/exercise_response.dart';
import '../../domain/models/workout_models.dart';
import '../../domain/repositories/workout_repository.dart';

class ApiWorkoutRepository implements WorkoutRepository {
  final ApiClient client;

  ApiWorkoutRepository(this.client);

  @override
  Future<List<ExerciseResponse>> getExercises() async {
    final response = await client.get('/exercises');
    final data = response.data as List<dynamic>? ?? const [];
    return data
        .map((e) => ExerciseResponse.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<WorkoutResult> saveWorkout(WorkoutRequest request) async {
    final response = await client.post('/workouts', data: request.toJson());
    return WorkoutResult.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PlanView> makeQuick5(String sessionId) async {
    try {
      // ApiClient chưa có patch(): gọi thẳng dio, interceptor vẫn gắn token
      // và đổi lỗi thành ApiException.
      final response = await client.dio.patch(
        '/plans/sessions/$sessionId',
        data: {'action': 'quick5'},
      );
      return PlanView.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException(
        code: 'NETWORK_ERROR',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
