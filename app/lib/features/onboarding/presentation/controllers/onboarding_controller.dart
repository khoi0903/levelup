import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/fake_plan_repository.dart';
import '../../domain/models/onboarding_models.dart';
import '../../domain/models/plan_models.dart';
import '../../domain/repositories/plan_repository.dart';

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return FakePlanRepository();
});

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController() : super(const OnboardingState());

  void selectGoal(UserGoal goal) {
    state = state.copyWith(goal: goal);
  }

  void updateBodyInfo({
    Gender? gender,
    int? birthYear,
    int? heightCm,
    int? startWeightKg,
    int? goalWeightKg,
  }) {
    state = state.copyWith(
      gender: gender,
      birthYear: birthYear,
      heightCm: heightCm,
      startWeightKg: startWeightKg,
      goalWeightKg: goalWeightKg,
    );
  }

  void updateTraining({
    Experience? experience,
    WorkoutLocation? location,
  }) {
    state = state.copyWith(
      experience: experience,
      location: location,
    );
  }

  void toggleEquipment(String item) {
    final list = List<String>.from(state.equipment);
    if (item == 'Không có') {
      state = state.copyWith(equipment: ['Không có']);
      return;
    }
    list.remove('Không có');
    if (list.contains(item)) {
      list.remove(item);
    } else {
      list.add(item);
    }
    state = state.copyWith(equipment: list);
  }

  void toggleInjury(BodyArea area) {
    final list = List<BodyArea>.from(state.injuries);
    if (list.contains(area)) {
      list.remove(area);
    } else {
      list.add(area);
    }
    state = state.copyWith(injuries: list);
  }

  void clearInjuries() {
    state = state.copyWith(injuries: const []);
  }

  void toggleWeekday(int day) {
    final list = List<int>.from(state.weekdays);
    if (list.contains(day)) {
      if (list.length > 1) {
        list.remove(day);
      }
    } else {
      list.add(day);
    }
    list.sort();
    state = state.copyWith(weekdays: list);
  }

  void setTimeSlot(TimeSlot slot) {
    state = state.copyWith(timeSlot: slot);
  }

  void setSessionMinutes(int minutes) {
    state = state.copyWith(sessionMinutes: minutes);
  }

  void toggleMotivationReason(String reason) {
    final list = List<String>.from(state.motivationReasons);
    if (list.contains(reason)) {
      list.remove(reason);
    } else {
      list.add(reason);
    }
    state = state.copyWith(motivationReasons: list);
  }

  void setMotivationText(String text) {
    state = state.copyWith(motivationText: text);
  }

  void setCoachStyle(CoachStyle style) {
    state = state.copyWith(coachStyle: style);
  }

  void setBuddyInvited(bool invited) {
    state = state.copyWith(buddyInvited: invited);
  }

  void setPushEnabled(bool enabled) {
    state = state.copyWith(pushEnabled: enabled);
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  return OnboardingController();
});

final weeklyPlanFutureProvider = FutureProvider<WeeklyPlan>((ref) async {
  final repo = ref.watch(planRepositoryProvider);
  final state = ref.watch(onboardingControllerProvider);
  return repo.generateInitialPlan(state);
});
