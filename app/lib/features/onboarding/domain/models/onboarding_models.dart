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
  final UserGoal goal;
  final Gender gender;
  final int birthYear;
  final int heightCm;
  final int startWeightKg;
  final int goalWeightKg;
  final Experience experience;
  final WorkoutLocation location;
  final List<String> equipment;
  final List<BodyArea> injuries;
  final List<int> weekdays; // 1 = T2, 7 = CN
  final TimeSlot timeSlot;
  final int sessionMinutes;
  final List<String> motivationReasons;
  final String motivationText;
  final CoachStyle coachStyle;
  final bool buddyInvited;
  final bool pushEnabled;

  const OnboardingState({
    this.goal = UserGoal.lose_fat,
    this.gender = Gender.male,
    this.birthYear = 1998,
    this.heightCm = 170,
    this.startWeightKg = 70,
    this.goalWeightKg = 65,
    this.experience = Experience.beginner,
    this.location = WorkoutLocation.home,
    this.equipment = const ['Tạ đơn', 'Thảm'],
    this.injuries = const [BodyArea.lower_back],
    this.weekdays = const [1, 3, 5],
    this.timeSlot = TimeSlot.evening,
    this.sessionMinutes = 15,
    this.motivationReasons = const ['Tự tin hơn khi soi gương', 'Mặc vừa đồ cũ'],
    this.motivationText = 'Muốn mặc lại chiếc sơ mi cũ trước Tết',
    this.coachStyle = CoachStyle.supportive,
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
    List<String>? equipment,
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
