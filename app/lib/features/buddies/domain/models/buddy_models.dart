class InviteResponse {
  final String code;
  final DateTime? expiresAt;
  final String shareText;

  const InviteResponse({
    required this.code,
    this.expiresAt,
    required this.shareText,
  });

  factory InviteResponse.fromJson(Map<String, dynamic> json) {
    return InviteResponse(
      code: json['code']?.toString() ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      shareText: json['shareText']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
        'shareText': shareText,
      };
}

class PairResponse {
  final String pairId;
  final String buddyName;
  final DateTime? since;

  const PairResponse({
    required this.pairId,
    required this.buddyName,
    this.since,
  });

  factory PairResponse.fromJson(Map<String, dynamic> json) {
    return PairResponse(
      pairId: json['pairId']?.toString() ?? '',
      buddyName: json['buddyName']?.toString() ?? '',
      since: json['since'] != null
          ? DateTime.tryParse(json['since'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'pairId': pairId,
        'buddyName': buddyName,
        if (since != null) 'since': since!.toIso8601String(),
      };
}

class BuddyWeekInfo {
  final String weekStart;
  final int completedSessions;
  final int targetSessions;

  const BuddyWeekInfo({
    required this.weekStart,
    required this.completedSessions,
    required this.targetSessions,
  });

  factory BuddyWeekInfo.fromJson(Map<String, dynamic> json) {
    return BuddyWeekInfo(
      weekStart: json['weekStart']?.toString() ?? '',
      completedSessions: (json['completedSessions'] as num?)?.toInt() ?? 0,
      targetSessions: (json['targetSessions'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'weekStart': weekStart,
        'completedSessions': completedSessions,
        'targetSessions': targetSessions,
      };
}

class BuddyInfo {
  final String displayName;
  final String localDate;
  final String status; // done | planned | rest | none
  final String? scheduledTime;
  final String? sessionTitle;
  final BuddyWeekInfo? week;
  final int streakWeeks;

  const BuddyInfo({
    required this.displayName,
    required this.localDate,
    required this.status,
    this.scheduledTime,
    this.sessionTitle,
    this.week,
    this.streakWeeks = 0,
  });

  bool get isDone => status == 'done';
  bool get isPlanned => status == 'planned';
  bool get isRest => status == 'rest';

  factory BuddyInfo.fromJson(Map<String, dynamic> json) {
    return BuddyInfo(
      displayName: json['displayName']?.toString() ?? '',
      localDate: json['localDate']?.toString() ?? '',
      status: json['status']?.toString() ?? 'none',
      scheduledTime: json['scheduledTime'] as String?,
      sessionTitle: json['sessionTitle'] as String?,
      week: json['week'] != null
          ? BuddyWeekInfo.fromJson(json['week'] as Map<String, dynamic>)
          : null,
      streakWeeks: (json['streakWeeks'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'localDate': localDate,
        'status': status,
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
        if (sessionTitle != null) 'sessionTitle': sessionTitle,
        if (week != null) 'week': week!.toJson(),
        'streakWeeks': streakWeeks,
      };
}

class BuddyMyActions {
  final bool nudged;
  final bool cheered;

  const BuddyMyActions({
    this.nudged = false,
    this.cheered = false,
  });

  BuddyMyActions copyWith({bool? nudged, bool? cheered}) {
    return BuddyMyActions(
      nudged: nudged ?? this.nudged,
      cheered: cheered ?? this.cheered,
    );
  }

  factory BuddyMyActions.fromJson(Map<String, dynamic> json) {
    return BuddyMyActions(
      nudged: json['nudged'] == true,
      cheered: json['cheered'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
        'nudged': nudged,
        'cheered': cheered,
      };
}

class BuddySharedInfo {
  final double? weightKg;
  final int? mealsKcalToday;

  const BuddySharedInfo({
    this.weightKg,
    this.mealsKcalToday,
  });

  factory BuddySharedInfo.fromJson(Map<String, dynamic> json) {
    return BuddySharedInfo(
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      mealsKcalToday: (json['mealsKcalToday'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (weightKg != null) 'weightKg': weightKg,
        if (mealsKcalToday != null) 'mealsKcalToday': mealsKcalToday,
      };
}

class BuddyTodayResponse {
  final String pairId;
  final DateTime? since;
  final int? sharedStreakWeeks;
  final BuddyInfo buddy;
  final BuddyMyActions myActionsToday;
  final BuddySharedInfo? shared;

  const BuddyTodayResponse({
    required this.pairId,
    this.since,
    this.sharedStreakWeeks,
    required this.buddy,
    required this.myActionsToday,
    this.shared,
  });

  BuddyTodayResponse copyWith({
    BuddyMyActions? myActionsToday,
  }) {
    return BuddyTodayResponse(
      pairId: pairId,
      since: since,
      sharedStreakWeeks: sharedStreakWeeks,
      buddy: buddy,
      myActionsToday: myActionsToday ?? this.myActionsToday,
      shared: shared,
    );
  }

  factory BuddyTodayResponse.fromJson(Map<String, dynamic> json) {
    return BuddyTodayResponse(
      pairId: json['pairId']?.toString() ?? '',
      since: json['since'] != null
          ? DateTime.tryParse(json['since'].toString())
          : null,
      sharedStreakWeeks: (json['sharedStreakWeeks'] as num?)?.toInt(),
      buddy: BuddyInfo.fromJson(json['buddy'] as Map<String, dynamic>),
      myActionsToday: json['myActionsToday'] != null
          ? BuddyMyActions.fromJson(json['myActionsToday'] as Map<String, dynamic>)
          : const BuddyMyActions(),
      shared: json['shared'] != null
          ? BuddySharedInfo.fromJson(json['shared'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'pairId': pairId,
        if (since != null) 'since': since!.toIso8601String(),
        if (sharedStreakWeeks != null) 'sharedStreakWeeks': sharedStreakWeeks,
        'buddy': buddy.toJson(),
        'myActionsToday': myActionsToday.toJson(),
        if (shared != null) 'shared': shared!.toJson(),
      };
}

class BuddyActionRequest {
  final String type; // nudge | cheer
  final String? message;

  const BuddyActionRequest({
    required this.type,
    this.message,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        if (message != null) 'message': message,
      };
}

class BuddyActionResponse {
  final String type;
  final String localDate;

  const BuddyActionResponse({
    required this.type,
    required this.localDate,
  });

  factory BuddyActionResponse.fromJson(Map<String, dynamic> json) {
    return BuddyActionResponse(
      type: json['type']?.toString() ?? '',
      localDate: json['localDate']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'localDate': localDate,
      };
}
