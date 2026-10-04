import '../../../onboarding/domain/models/plan_models.dart';

class CoachInjuryView {
  final String bodyArea;
  final String? note;

  const CoachInjuryView({
    required this.bodyArea,
    this.note,
  });

  factory CoachInjuryView.fromJson(Map<String, dynamic> json) {
    return CoachInjuryView(
      bodyArea: json['bodyArea']?.toString() ?? '',
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'bodyArea': bodyArea,
        if (note != null) 'note': note,
      };
}

class CoachCardView {
  final String? type; // adjust_session | add_injury
  final String status; // proposed | applied
  final String? planId;
  final String? sessionId;
  final String? change;
  final String? fromExerciseId;
  final String? fromExerciseName;
  final String? toExerciseId;
  final String? toExerciseName;
  final String? reason;
  final CoachInjuryView? injury;
  final SessionView? preview;

  const CoachCardView({
    this.type,
    required this.status,
    this.planId,
    this.sessionId,
    this.change,
    this.fromExerciseId,
    this.fromExerciseName,
    this.toExerciseId,
    this.toExerciseName,
    this.reason,
    this.injury,
    this.preview,
  });

  bool get isProposed => status == 'proposed';
  bool get isApplied => status == 'applied';

  CoachCardView copyWith({String? status}) {
    return CoachCardView(
      type: type,
      status: status ?? this.status,
      planId: planId,
      sessionId: sessionId,
      change: change,
      fromExerciseId: fromExerciseId,
      fromExerciseName: fromExerciseName,
      toExerciseId: toExerciseId,
      toExerciseName: toExerciseName,
      reason: reason,
      injury: injury,
      preview: preview,
    );
  }

  factory CoachCardView.fromJson(Map<String, dynamic> json) {
    return CoachCardView(
      type: json['type'] as String?,
      status: json['status']?.toString() ?? 'proposed',
      planId: json['planId'] as String?,
      sessionId: json['sessionId'] as String?,
      change: json['change'] as String?,
      fromExerciseId: json['fromExerciseId'] as String?,
      fromExerciseName: json['fromExerciseName'] as String?,
      toExerciseId: json['toExerciseId'] as String?,
      toExerciseName: json['toExerciseName'] as String?,
      reason: json['reason'] as String?,
      injury: json['injury'] != null
          ? CoachInjuryView.fromJson(json['injury'] as Map<String, dynamic>)
          : null,
      preview: json['preview'] != null
          ? SessionView.fromJson(json['preview'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        if (type != null) 'type': type,
        'status': status,
        if (planId != null) 'planId': planId,
        if (sessionId != null) 'sessionId': sessionId,
        if (change != null) 'change': change,
        if (fromExerciseId != null) 'fromExerciseId': fromExerciseId,
        if (fromExerciseName != null) 'fromExerciseName': fromExerciseName,
        if (toExerciseId != null) 'toExerciseId': toExerciseId,
        if (toExerciseName != null) 'toExerciseName': toExerciseName,
        if (reason != null) 'reason': reason,
        if (injury != null) 'injury': injury!.toJson(),
        if (preview != null) 'preview': preview!.toJson(),
      };
}

class CoachMessageView {
  final String id;
  final String role; // user | coach | event
  final String content;
  final DateTime? createdAt;
  final CoachCardView? card;

  const CoachMessageView({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
    this.card,
  });

  bool get isUser => role == 'user';
  bool get isCoach => role == 'coach';
  bool get isEvent => role == 'event';

  CoachMessageView copyWith({CoachCardView? card}) {
    return CoachMessageView(
      id: id,
      role: role,
      content: content,
      createdAt: createdAt,
      card: card ?? this.card,
    );
  }

  factory CoachMessageView.fromJson(Map<String, dynamic> json) {
    return CoachMessageView(
      id: json['id']?.toString() ?? '',
      role: json['role']?.toString() ?? 'coach',
      content: json['content']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      card: json['card'] != null
          ? CoachCardView.fromJson(json['card'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
        if (card != null) 'card': card!.toJson(),
      };
}

class SendCoachResponse {
  final CoachMessageView userMessage;
  final CoachMessageView reply;
  final int remainingToday;
  final String source;

  const SendCoachResponse({
    required this.userMessage,
    required this.reply,
    required this.remainingToday,
    required this.source,
  });

  factory SendCoachResponse.fromJson(Map<String, dynamic> json) {
    return SendCoachResponse(
      userMessage: CoachMessageView.fromJson(json['userMessage'] as Map<String, dynamic>),
      reply: CoachMessageView.fromJson(json['reply'] as Map<String, dynamic>),
      remainingToday: (json['remainingToday'] as num?)?.toInt() ?? 0,
      source: json['source']?.toString() ?? 'rules',
    );
  }

  Map<String, dynamic> toJson() => {
        'userMessage': userMessage.toJson(),
        'reply': reply.toJson(),
        'remainingToday': remainingToday,
        'source': source,
      };
}

class CoachHistoryResponse {
  final List<CoachMessageView> messages;
  final String? nextBefore;

  const CoachHistoryResponse({
    required this.messages,
    this.nextBefore,
  });

  factory CoachHistoryResponse.fromJson(Map<String, dynamic> json) {
    return CoachHistoryResponse(
      messages: (json['messages'] as List<dynamic>?)
              ?.map((e) => CoachMessageView.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      nextBefore: json['nextBefore']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'messages': messages.map((m) => m.toJson()).toList(),
        if (nextBefore != null) 'nextBefore': nextBefore,
      };
}
