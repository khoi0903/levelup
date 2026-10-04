import 'me_response.dart';

/// Mô hình cho PATCH /me, khớp chính xác backend vn.levelup.users.SettingsRequest.
/// Chỉ gửi các trường cần thay đổi (null = giữ nguyên).
class NotificationsUpdate {
  final bool? pushEnabled;
  final String? checkinTime;
  final int? preWorkoutMinutes;
  final String? quietStart;
  final String? quietEnd;
  final int? maxPerDay;
  final bool? waterReminder;

  const NotificationsUpdate({
    this.pushEnabled,
    this.checkinTime,
    this.preWorkoutMinutes,
    this.quietStart,
    this.quietEnd,
    this.maxPerDay,
    this.waterReminder,
  });

  Map<String, dynamic> toJson() => {
    if (pushEnabled != null) 'pushEnabled': pushEnabled,
    if (checkinTime != null) 'checkinTime': checkinTime,
    if (preWorkoutMinutes != null) 'preWorkoutMinutes': preWorkoutMinutes,
    if (quietStart != null) 'quietStart': quietStart,
    if (quietEnd != null) 'quietEnd': quietEnd,
    if (maxPerDay != null) 'maxPerDay': maxPerDay,
    if (waterReminder != null) 'waterReminder': waterReminder,
  };

  bool get isEmpty =>
      pushEnabled == null &&
      checkinTime == null &&
      preWorkoutMinutes == null &&
      quietStart == null &&
      quietEnd == null &&
      maxPerDay == null &&
      waterReminder == null;
}

class SharingUpdate {
  final bool? weight;
  final bool? measurements;
  final bool? photos;
  final bool? meals;

  const SharingUpdate({
    this.weight,
    this.measurements,
    this.photos,
    this.meals,
  });

  Map<String, dynamic> toJson() => {
    if (weight != null) 'weight': weight,
    if (measurements != null) 'measurements': measurements,
    if (photos != null) 'photos': photos,
    if (meals != null) 'meals': meals,
  };

  bool get isEmpty =>
      weight == null && measurements == null && photos == null && meals == null;
}

class SettingsRequest {
  final String? displayName;
  final String? timezone;
  final String? coachStyle;
  final String? goal;
  final int? sessionMinutes;
  final List<UserAvailabilitySlot>? availability;
  final NotificationsUpdate? notifications;
  final SharingUpdate? sharing;

  const SettingsRequest({
    this.displayName,
    this.timezone,
    this.coachStyle,
    this.goal,
    this.sessionMinutes,
    this.availability,
    this.notifications,
    this.sharing,
  });

  Map<String, dynamic> toJson() => {
    if (displayName != null) 'displayName': displayName,
    if (timezone != null) 'timezone': timezone,
    if (coachStyle != null) 'coachStyle': coachStyle,
    if (goal != null) 'goal': goal,
    if (sessionMinutes != null) 'sessionMinutes': sessionMinutes,
    if (availability != null)
      'availability': availability!.map((s) => s.toJson()).toList(),
    if (notifications != null && !notifications!.isEmpty)
      'notifications': notifications!.toJson(),
    if (sharing != null && !sharing!.isEmpty) 'sharing': sharing!.toJson(),
  };
}
