import '../models/streak_models.dart';

abstract class StreakRepository {
  Future<StreakView> getStreak();
}
