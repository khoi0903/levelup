// ignore_for_file: constant_identifier_names

enum UserGoal {
  lose_fat,
  build_muscle,
  get_healthier,
  maintain,
}

enum Gender {
  male,
  female,
  other,
}

enum Experience {
  beginner,
  intermediate,
  regular,
}

enum WorkoutLocation {
  home,
  gym,
  outdoor,
}

enum Equipment {
  dumbbell,
  mat,
  resistance_band,
  pullup_bar,
}

enum CoachStyle {
  strict,
  supportive,
  funny,
}

enum BodyArea {
  lower_back,
  knee,
  shoulder,
  neck,
  wrist,
  ankle,
  hip,
  other,
}

enum TimeSlot {
  early_morning,
  noon,
  evening,
  late_evening,
}

class OnboardingState {
  final UserGoal? goal;
  final Gender? gender;
  final int? birthYear;
  final int? heightCm;
  final int? startWeightKg;
  final int? goalWeightKg;
  final Experience? experience;
  final WorkoutLocation? location;
  final List<Equipment> equipment;
  final List<BodyArea> injuries;
  final List<int> weekdays; // 1 = T2, 7 = CN
  final TimeSlot? timeSlot;
  final int? sessionMinutes;
  final List<String> motivationReasons;
  final String motivationText;
  final CoachStyle? coachStyle;
  final bool buddyInvited;
  final bool pushEnabled;

  const OnboardingState({
    this.goal,
    this.gender,
    this.birthYear,
    this.heightCm,
    this.startWeightKg,
    this.goalWeightKg,
    this.experience,
    this.location,
    this.equipment = const [],
    this.injuries = const [],
    this.weekdays = const [],
    this.timeSlot,
    this.sessionMinutes,
    this.motivationReasons = const [],
    this.motivationText = '',
    this.coachStyle,
    this.buddyInvited = false,
    this.pushEnabled = true,
  });

  OnboardingState copyWith({
    UserGoal? goal,
    Gender? gender,
    int? birthYear,
    int? heightCm,
    int? startWeightKg,
    int? goalWeightKg,
    Experience? experience,
    WorkoutLocation? location,
    List<Equipment>? equipment,
    List<BodyArea>? injuries,
    List<int>? weekdays,
    TimeSlot? timeSlot,
    int? sessionMinutes,
    List<String>? motivationReasons,
    String? motivationText,
    CoachStyle? coachStyle,
    bool? buddyInvited,
    bool? pushEnabled,
  }) {
    return OnboardingState(
      goal: goal ?? this.goal,
      gender: gender ?? this.gender,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      startWeightKg: startWeightKg ?? this.startWeightKg,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      experience: experience ?? this.experience,
      location: location ?? this.location,
      equipment: equipment ?? this.equipment,
      injuries: injuries ?? this.injuries,
      weekdays: weekdays ?? this.weekdays,
      timeSlot: timeSlot ?? this.timeSlot,
      sessionMinutes: sessionMinutes ?? this.sessionMinutes,
      motivationReasons: motivationReasons ?? this.motivationReasons,
      motivationText: motivationText ?? this.motivationText,
      coachStyle: coachStyle ?? this.coachStyle,
      buddyInvited: buddyInvited ?? this.buddyInvited,
      pushEnabled: pushEnabled ?? this.pushEnabled,
    );
  }
}
