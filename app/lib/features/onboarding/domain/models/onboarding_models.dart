// ignore_for_file: constant_identifier_names

import 'plan_models.dart';

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
  final String displayName;
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

  /// Tỉ lệ mỡ cơ thể (%) theo vóc dáng đã chọn, null nếu bỏ qua.
  final int? bodyFatPct;

  /// Nhóm cơ muốn cải thiện: chest, back, shoulders, arms, abs, glutes, legs.
  final List<String> focusMuscles;

  const OnboardingState({
    this.displayName = '',
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
    this.bodyFatPct,
    this.focusMuscles = const [],
  });

  OnboardingState copyWith({
    String? displayName,
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
    int? bodyFatPct,
    bool clearBodyFatPct = false,
    List<String>? focusMuscles,
  }) {
    return OnboardingState(
      displayName: displayName ?? this.displayName,
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
      bodyFatPct: clearBodyFatPct ? null : (bodyFatPct ?? this.bodyFatPct),
      focusMuscles: focusMuscles ?? this.focusMuscles,
    );
  }

  Map<String, dynamic> toOnboardingRequestJson() {
    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw StateError('displayName is required and cannot be empty');
    }
    if (goal == null) {
      throw StateError('goal is required');
    }
    if (heightCm == null) {
      throw StateError('heightCm is required');
    }
    if (startWeightKg == null) {
      throw StateError('weightKg (startWeightKg) is required');
    }
    if (experience == null) {
      throw StateError('experience is required');
    }
    if (location == null) {
      throw StateError('location is required');
    }
    if (timeSlot == null) {
      throw StateError('timeSlot is required');
    }
    if (weekdays.isEmpty) {
      throw StateError('availability weekdays is required');
    }
    if (sessionMinutes == null) {
      throw StateError('sessionMinutes is required');
    }
    if (coachStyle == null) {
      throw StateError('coachStyle is required');
    }

    final availabilityList = weekdays.map((day) => {
      'weekday': day,
      'slot': timeSlot!.name,
    }).toList();

    return {
      'displayName': trimmedName,
      'goal': goal!.name,
      if (gender != null) 'gender': gender!.name,
      if (birthYear != null) 'birthYear': birthYear,
      'heightCm': heightCm!.toDouble(),
      'weightKg': startWeightKg!.toDouble(),
      if (goalWeightKg != null) 'goalWeightKg': goalWeightKg!.toDouble(),
      'experience': experience!.name,
      'location': location!.name,
      'equipment': equipment.map((e) => e.name).toList(),
      'injuries': injuries.map((i) => i.name).toList(),
      'availability': availabilityList,
      'sessionMinutes': sessionMinutes!,
      if (motivationReasons.isNotEmpty) 'motivationReasons': motivationReasons,
      if (motivationText.trim().isNotEmpty) 'motivationText': motivationText.trim(),
      'coachStyle': coachStyle!.name,
      'timezone': 'Asia/Ho_Chi_Minh',
      if (bodyFatPct != null) 'bodyFatPct': bodyFatPct!.clamp(5, 50),
      if (focusMuscles.isNotEmpty) 'focusMuscles': focusMuscles,
    };
  }
}

class OnboardingResponse {
  final String userId;
  final String displayName;
  final NutritionTarget? nutritionTarget;
  final PlanView? plan;

  const OnboardingResponse({
    required this.userId,
    required this.displayName,
    this.nutritionTarget,
    this.plan,
  });

  factory OnboardingResponse.fromJson(Map<String, dynamic> json) {
    return OnboardingResponse(
      userId: json['userId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      nutritionTarget: json['nutritionTarget'] != null
          ? NutritionTarget.fromJson(json['nutritionTarget'] as Map<String, dynamic>)
          : null,
      plan: json['plan'] != null
          ? PlanView.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'displayName': displayName,
        if (nutritionTarget != null) 'nutritionTarget': nutritionTarget!.toJson(),
        if (plan != null) 'plan': plan!.toJson(),
      };
}
