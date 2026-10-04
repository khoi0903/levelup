import '../../../onboarding/domain/models/plan_models.dart';

class SkipReportRequest {
  final String? plannedSessionId;
  final String reason; // busy | tired | pain | bored | forgot | other
  final String? note;
  final String? bodyArea; // lower_back | knee | shoulder | neck | wrist | ankle | hip | other

  const SkipReportRequest({
    this.plannedSessionId,
    required this.reason,
    this.note,
    this.bodyArea,
  });

  Map<String, dynamic> toJson() => {
        if (plannedSessionId != null) 'plannedSessionId': plannedSessionId,
        'reason': reason,
        if (note != null) 'note': note,
        if (bodyArea != null) 'bodyArea': bodyArea,
      };
}

class SkipReportResponse {
  final String action;
  final PlanView? plan;
  final String message;
  final Map<String, dynamic>? suggestion;

  const SkipReportResponse({
    required this.action,
    this.plan,
    required this.message,
    this.suggestion,
  });

  factory SkipReportResponse.fromJson(Map<String, dynamic> json) {
    return SkipReportResponse(
      action: json['action']?.toString() ?? 'none',
      plan: json['plan'] != null
          ? PlanView.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
      message: json['message']?.toString() ?? '',
      suggestion: json['suggestion'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() => {
        'action': action,
        if (plan != null) 'plan': plan!.toJson(),
        'message': message,
        if (suggestion != null) 'suggestion': suggestion,
      };
}

class PatchSessionRequest {
  final String action; // reschedule | quick5 | rest
  final String? scheduledDate;
  final String? scheduledTime;

  const PatchSessionRequest({
    required this.action,
    this.scheduledDate,
    this.scheduledTime,
  });

  Map<String, dynamic> toJson() => {
        'action': action,
        if (scheduledDate != null) 'scheduledDate': scheduledDate,
        if (scheduledTime != null) 'scheduledTime': scheduledTime,
      };
}
