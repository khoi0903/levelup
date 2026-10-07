import '../../domain/models/onboarding_models.dart';
import '../../domain/models/plan_models.dart';
import '../../domain/repositories/plan_repository.dart';

class FakePlanRepository implements PlanRepository {
  PlanView? planView;

  FakePlanRepository({this.planView});

  @override
  Future<PlanView> getCurrentPlan() async {
    if (planView != null) {
      return planView!;
    }
    return const PlanView(
      id: 'fake-plan-1',
      weekStart: '2026-10-05',
      status: 'active',
      targetSessions: 3,
      sessions: [
        SessionView(
          id: 'session-1',
          scheduledDate: '2026-10-05',
          scheduledTime: '18:00',
          title: 'Toàn thân cơ bản',
          durationMin: 12,
          status: 'pending',
          items: [
            ItemView(exerciseId: 'ex1', nameVi: 'Bật nhảy tại chỗ', reps: 15),
            ItemView(exerciseId: 'ex2', nameVi: 'Squat không tạ', reps: 10),
            ItemView(exerciseId: 'ex3', nameVi: 'Plank', durationSec: 30),
          ],
        ),
        SessionView(
          id: 'session-2',
          scheduledDate: '2026-10-07',
          scheduledTime: '18:00',
          title: 'Cardio nhẹ + core',
          durationMin: 10,
          status: 'pending',
          items: [
            ItemView(exerciseId: 'ex4', nameVi: 'Nâng cao đùi', reps: 20),
            ItemView(exerciseId: 'ex5', nameVi: 'Gập bụng', reps: 12),
          ],
        ),
        SessionView(
          id: 'session-3',
          scheduledDate: '2026-10-09',
          scheduledTime: '18:00',
          title: 'Toàn thân + giãn cơ',
          durationMin: 15,
          status: 'pending',
          items: [
            ItemView(exerciseId: 'ex1', nameVi: 'Bật nhảy tại chỗ', reps: 15),
            ItemView(exerciseId: 'ex6', nameVi: 'Giãn cơ toàn thân', durationSec: 60),
          ],
        ),
      ],
    );
  }

  @override
  Future<PlanView> generateInitialPlan(OnboardingState state) async {
    final hasLowerBack = state.injuries.contains(BodyArea.lower_back);
    final base = await getCurrentPlan();

    return PlanView(
      id: base.id,
      weekStart: base.weekStart,
      status: base.status,
      targetSessions: base.targetSessions,
      sessions: base.sessions,
      injuryNote: hasLowerBack
          ? 'Đã bỏ các động tác gây áp lực lên lưng dưới'
          : (state.injuries.isNotEmpty
              ? 'Đã điều chỉnh các bài tập theo tình trạng chấn thương của bạn'
              : null),
    );
  }
}
