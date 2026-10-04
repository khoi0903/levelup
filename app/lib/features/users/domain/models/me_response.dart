import '../../../workout/domain/models/workout_models.dart';

class UserProfile {
  final String? goal;
  final String? gender;
  final int? birthYear;
  final double? heightCm;
  final double? startWeightKg;
  final double? goalWeightKg;
  final String? experience;
  final String? location;
  final int? sessionMinutes;
  final String? coachStyle;
  final List<String> motivationReasons;
  final String? motivationText;
  final List<String> equipment;
  final String? onboardingCompletedAt;

  const UserProfile({
    this.goal,
    this.gender,
    this.birthYear,
    this.heightCm,
    this.startWeightKg,
    this.goalWeightKg,
    this.experience,
    this.location,
    this.sessionMinutes,
    this.coachStyle,
    this.motivationReasons = const [],
    this.motivationText,
    this.equipment = const [],
    this.onboardingCompletedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      goal: json['goal'] as String?,
      gender: json['gender'] as String?,
      birthYear: (json['birthYear'] as num?)?.toInt(),
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      startWeightKg: (json['startWeightKg'] as num?)?.toDouble(),
      goalWeightKg: (json['goalWeightKg'] as num?)?.toDouble(),
      experience: json['experience'] as String?,
      location: json['location'] as String?,
      sessionMinutes: (json['sessionMinutes'] as num?)?.toInt(),
      coachStyle: json['coachStyle'] as String?,
      motivationReasons: (json['motivationReasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      motivationText: json['motivationText'] as String?,
      equipment: (json['equipment'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      onboardingCompletedAt: json['onboardingCompletedAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (goal != null) 'goal': goal,
        if (gender != null) 'gender': gender,
        if (birthYear != null) 'birthYear': birthYear,
        if (heightCm != null) 'heightCm': heightCm,
        if (startWeightKg != null) 'startWeightKg': startWeightKg,
        if (goalWeightKg != null) 'goalWeightKg': goalWeightKg,
        if (experience != null) 'experience': experience,
        if (location != null) 'location': location,
        if (sessionMinutes != null) 'sessionMinutes': sessionMinutes,
        if (coachStyle != null) 'coachStyle': coachStyle,
        'motivationReasons': motivationReasons,
        if (motivationText != null) 'motivationText': motivationText,
        'equipment': equipment,
        if (onboardingCompletedAt != null)
          'onboardingCompletedAt': onboardingCompletedAt,
      };
}

class UserStreak {
  final int currentWeeks;
  final int bestWeeks;
  final int freezesAvailable;
  final String? lastClosedWeek;

  const UserStreak({
    this.currentWeeks = 0,
    this.bestWeeks = 0,
    this.freezesAvailable = 0,
    this.lastClosedWeek,
  });

  factory UserStreak.fromJson(Map<String, dynamic> json) {
    return UserStreak(
      currentWeeks: (json['currentWeeks'] as num?)?.toInt() ?? 0,
      bestWeeks: (json['bestWeeks'] as num?)?.toInt() ?? 0,
      freezesAvailable: (json['freezesAvailable'] as num?)?.toInt() ?? 0,
      lastClosedWeek: json['lastClosedWeek'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'currentWeeks': currentWeeks,
        'bestWeeks': bestWeeks,
        'freezesAvailable': freezesAvailable,
        if (lastClosedWeek != null) 'lastClosedWeek': lastClosedWeek,
      };
}

class UserNotificationsSettings {
  final bool pushEnabled;
  final String? checkinTime;
  final int? preWorkoutMinutes;
  final String quietStart;
  final String quietEnd;
  final int maxPerDay;

  const UserNotificationsSettings({
    this.pushEnabled = true,
    this.checkinTime,
    this.preWorkoutMinutes,
    this.quietStart = '22:00',
    this.quietEnd = '07:00',
    this.maxPerDay = 2,
  });

  factory UserNotificationsSettings.fromJson(Map<String, dynamic> json) {
    return UserNotificationsSettings(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      checkinTime: json['checkinTime'] as String?,
      preWorkoutMinutes: (json['preWorkoutMinutes'] as num?)?.toInt(),
      quietStart: json['quietStart'] as String? ?? '22:00',
      quietEnd: json['quietEnd'] as String? ?? '07:00',
      maxPerDay: (json['maxPerDay'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushEnabled': pushEnabled,
        if (checkinTime != null) 'checkinTime': checkinTime,
        if (preWorkoutMinutes != null) 'preWorkoutMinutes': preWorkoutMinutes,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'maxPerDay': maxPerDay,
      };
}

class UserSharingSettings {
  final bool weight;
  final bool measurements;
  final bool photos;
  final bool meals;

  const UserSharingSettings({
    this.weight = false,
    this.measurements = false,
    this.photos = false,
    this.meals = false,
  });

  factory UserSharingSettings.fromJson(Map<String, dynamic> json) {
    return UserSharingSettings(
      weight: json['weight'] as bool? ?? false,
      measurements: json['measurements'] as bool? ?? false,
      photos: json['photos'] as bool? ?? false,
      meals: json['meals'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'weight': weight,
        'measurements': measurements,
        'photos': photos,
        'meals': meals,
      };
}

class UserAvailabilitySlot {
  final int weekday; // 1-7
  final String slot; // early_morning | morning | noon | afternoon | evening | late_evening

  const UserAvailabilitySlot({
    required this.weekday,
    required this.slot,
  });

  factory UserAvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return UserAvailabilitySlot(
      weekday: (json['weekday'] as num?)?.toInt() ?? 1,
      slot: json['slot']?.toString() ?? 'evening',
    );
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        'slot': slot,
      };
}

class UserSettings {
  final UserNotificationsSettings notifications;
  final UserSharingSettings sharing;
  final List<UserAvailabilitySlot> availability;

  const UserSettings({
    this.notifications = const UserNotificationsSettings(),
    this.sharing = const UserSharingSettings(),
    this.availability = const [],
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      notifications: json['notifications'] != null
          ? UserNotificationsSettings.fromJson(json['notifications'] as Map<String, dynamic>)
          : const UserNotificationsSettings(),
      sharing: json['sharing'] != null
          ? UserSharingSettings.fromJson(json['sharing'] as Map<String, dynamic>)
          : const UserSharingSettings(),
      availability: (json['availability'] as List<dynamic>?)
              ?.map((e) => UserAvailabilitySlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'notifications': notifications.toJson(),
        'sharing': sharing.toJson(),
        'availability': availability.map((a) => a.toJson()).toList(),
      };
}

class MeResponse {
  final String id;
  final String displayName;
  final String? timezone;
  final String? localDate;
  final String? weekStart;
  final UserProfile? profile;
  final UserStreak? streak;
  final UserSettings settings;
  final List<Achievement> achievements;

  const MeResponse({
    required this.id,
    required this.displayName,
    this.timezone,
    this.localDate,
    this.weekStart,
    this.profile,
    this.streak,
    this.settings = const UserSettings(),
    this.achievements = const [],
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    return MeResponse(
      id: json['id']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      timezone: json['timezone'] as String?,
      localDate: json['localDate'] as String?,
      weekStart: json['weekStart'] as String?,
      profile: json['profile'] != null
          ? UserProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      streak: json['streak'] != null
          ? UserStreak.fromJson(json['streak'] as Map<String, dynamic>)
          : null,
      settings: json['settings'] != null
          ? UserSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : const UserSettings(),
      achievements: (json['achievements'] as List<dynamic>?)
              ?.map((e) => Achievement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        if (timezone != null) 'timezone': timezone,
        if (localDate != null) 'localDate': localDate,
        if (weekStart != null) 'weekStart': weekStart,
        if (profile != null) 'profile': profile!.toJson(),
        if (streak != null) 'streak': streak!.toJson(),
        'settings': settings.toJson(),
        'achievements': achievements.map((a) => a.toJson()).toList(),
      };
}
