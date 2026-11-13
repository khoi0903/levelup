import '../models/body_models.dart';

abstract class BodyRepository {
  /// GET /me/body
  Future<BodyStats> getBody();

  /// GET /me/muscles/week?weekStart=YYYY-MM-DD (bỏ trống = tuần hiện tại).
  Future<MuscleWeek> getMusclesWeek({String? weekStart});
}
