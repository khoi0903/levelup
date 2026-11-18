import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/utils/cache_for_extension.dart';
import '../../data/repositories/api_onboarding_repository.dart';
import '../../data/repositories/api_plan_repository.dart';
import '../../domain/models/onboarding_models.dart';
import '../../domain/models/plan_models.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../../domain/repositories/plan_repository.dart';

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiPlanRepository(client);
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiOnboardingRepository(client);
});

final onboardingResponseProvider =
    StateProvider<OnboardingResponse?>((ref) => null);

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController() : super(const OnboardingState());

  void reset() {
    state = const OnboardingState();
  }

  void setDisplayName(String name) {
    state = state.copyWith(displayName: name);
  }

  void selectGoal(UserGoal goal) {
    state = state.copyWith(goal: goal);
  }

  void setGender(Gender gender) {
    state = state.copyWith(gender: gender);
  }

  void updateBodyInfo({
    Gender? gender,
    int? birthYear,
    int? heightCm,
    int? startWeightKg,
    int? goalWeightKg,
  }) {
    state = OnboardingState(
      displayName: state.displayName,
      goal: state.goal,
      gender: gender ?? state.gender,
      birthYear: birthYear,
      heightCm: heightCm,
      startWeightKg: startWeightKg,
      goalWeightKg: goalWeightKg,
      experience: state.experience,
      location: state.location,
      equipment: state.equipment,
      injuries: state.injuries,
      weekdays: state.weekdays,
      timeSlot: state.timeSlot,
      dayTimes: state.dayTimes,
      sessionMinutes: state.sessionMinutes,
      motivationReasons: state.motivationReasons,
      motivationText: state.motivationText,
      coachStyle: state.coachStyle,
      buddyInvited: state.buddyInvited,
      pushEnabled: state.pushEnabled,
      bodyFatPct: state.bodyFatPct,
      focusMuscles: state.focusMuscles,
    );
  }

  /// Vóc dáng đã chọn (tỉ lệ mỡ %), null = bỏ qua.
  void setBodyFatPct(int? pct) {
    state = pct == null
        ? state.copyWith(clearBodyFatPct: true)
        : state.copyWith(bodyFatPct: pct);
  }

  void toggleFocusMuscle(String muscle) {
    final list = List<String>.from(state.focusMuscles);
    if (!list.remove(muscle)) list.add(muscle);
    state = state.copyWith(focusMuscles: list);
  }

  void clearFocusMuscles() {
    state = state.copyWith(focusMuscles: const []);
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

  void toggleEquipment(Equipment item) {
    final list = List<Equipment>.from(state.equipment);
    if (list.contains(item)) {
      list.remove(item);
    } else {
      list.add(item);
    }
    state = state.copyWith(equipment: list);
  }

  void clearEquipment() {
    state = state.copyWith(equipment: const []);
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
      list.remove(day);
    } else {
      list.add(day);
    }
    list.sort();
    final times = Map<int, String>.from(state.dayTimes)
      ..removeWhere((d, _) => !list.contains(d));
    state = state.copyWith(weekdays: list, dayTimes: times);
  }

  /// Đặt giờ riêng cho một ngày ("HH:mm"), null = dùng giờ mặc định của khung.
  void setDayTime(int weekday, String? time) {
    final times = Map<int, String>.from(state.dayTimes);
    if (time == null) {
      times.remove(weekday);
    } else {
      times[weekday] = time;
    }
    state = state.copyWith(dayTimes: times);
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

final weeklyPlanFutureProvider =
    FutureProvider.autoDispose<PlanView>((ref) async {
  ref.cacheFor(const Duration(minutes: 5));
  final response = ref.watch(onboardingResponseProvider);
  if (response?.plan != null) {
    return response!.plan!;
  }
  final repo = ref.watch(planRepositoryProvider);
  return repo.getCurrentPlan();
});
