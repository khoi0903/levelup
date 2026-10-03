import '../../domain/models/onboarding_models.dart';
import '../../domain/models/plan_models.dart';
import '../../domain/repositories/plan_repository.dart';

class FakePlanRepository implements PlanRepository {
  @override
  Future<WeeklyPlan> generateInitialPlan(OnboardingState state) async {
    // Giả lập độ trễ nhỏ nếu cần, ở đây trả dữ liệu mẫu chuẩn theo wireframe
    final hasLowerBack = state.injuries.contains(BodyArea.lower_back);

    return WeeklyPlan(
      title: 'Kế hoạch tuần 1 của bạn',
      subtitle: '3 buổi ngắn để làm quen. Coach sẽ tăng dần theo sức của bạn.',
      injuryNote: hasLowerBack
          ? 'Đã bỏ các động tác gây áp lực lên lưng dưới'
          : (state.injuries.isNotEmpty
              ? 'Đã điều chỉnh các bài tập theo tình trạng chấn thương của bạn'
              : null),
      sessions: const [
        WorkoutSessionItem(
          dayLabel: 'T2',
          title: 'Toàn thân cơ bản',
          durationMinutes: 12,
          exerciseCount: 6,
        ),
        WorkoutSessionItem(
          dayLabel: 'T4',
          title: 'Cardio nhẹ + core',
          durationMinutes: 10,
          exerciseCount: 5,
        ),
        WorkoutSessionItem(
          dayLabel: 'T6',
          title: 'Toàn thân + giãn cơ',
          durationMinutes: 15,
          exerciseCount: 7,
        ),
      ],
    );
  }
}
