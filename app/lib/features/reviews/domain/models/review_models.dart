import '../../../onboarding/domain/models/plan_models.dart';

class ReviewWin {
  final String type; // pr | streak | habit | other
  final String label;

  const ReviewWin({
    required this.type,
    required this.label,
  });

  factory ReviewWin.fromJson(Map<String, dynamic> json) {
    return ReviewWin(
      type: json['type']?.toString() ?? 'other',
      label: json['label']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
      };
}

class WeeklyReviewView {
  final String id;
  final String weekStart;
  final int sessionsDone;
  final int sessionsTarget;
  final int completionPct;
  final int totalMinutes;
  final double? avgRpe;
  final String recommendation; // increase | keep | decrease
  final String? win;
  final List<ReviewWin> wins;
  final String? improvement;
  final String? nextWeekSummary;
  final double? weightChangeKg;
  final String decision; // pending | accepted | adjusted | dismissed
  final String? source;
  final DateTime? generatedAt;
  final PlanView? plan;

  const WeeklyReviewView({
    required this.id,
    required this.weekStart,
    required this.sessionsDone,
    required this.sessionsTarget,
    required this.completionPct,
    required this.totalMinutes,
    this.avgRpe,
    required this.recommendation,
    this.win,
    this.wins = const [],
    this.improvement,
    this.nextWeekSummary,
    this.weightChangeKg,
    required this.decision,
    this.source,
    this.generatedAt,
    this.plan,
  });

  bool get isPending => decision == 'pending';
  bool get isAccepted => decision == 'accepted';
  bool get isAdjusted => decision == 'adjusted';

  factory WeeklyReviewView.fromJson(Map<String, dynamic> json) {
    return WeeklyReviewView(
      id: json['id']?.toString() ?? '',
      weekStart: json['weekStart']?.toString() ?? '',
      sessionsDone: (json['sessionsDone'] as num?)?.toInt() ?? 0,
      sessionsTarget: (json['sessionsTarget'] as num?)?.toInt() ?? 0,
      completionPct: (json['completionPct'] as num?)?.toInt() ?? 0,
      totalMinutes: (json['totalMinutes'] as num?)?.toInt() ?? 0,
      avgRpe: (json['avgRpe'] as num?)?.toDouble(),
      recommendation: json['recommendation']?.toString() ?? 'keep',
      win: json['win'] as String?,
      wins: (json['wins'] as List<dynamic>?)
              ?.map((e) => ReviewWin.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      improvement: json['improvement'] as String?,
      nextWeekSummary: json['nextWeekSummary'] as String?,
      weightChangeKg: (json['weightChangeKg'] as num?)?.toDouble(),
      decision: json['decision']?.toString() ?? 'pending',
      source: json['source'] as String?,
      generatedAt: json['generatedAt'] != null
          ? DateTime.tryParse(json['generatedAt'].toString())
          : null,
      plan: json['plan'] != null
          ? PlanView.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'weekStart': weekStart,
        'sessionsDone': sessionsDone,
        'sessionsTarget': sessionsTarget,
        'completionPct': completionPct,
        'totalMinutes': totalMinutes,
        if (avgRpe != null) 'avgRpe': avgRpe,
        'recommendation': recommendation,
        if (win != null) 'win': win,
        'wins': wins.map((w) => w.toJson()).toList(),
        if (improvement != null) 'improvement': improvement,
        if (nextWeekSummary != null) 'nextWeekSummary': nextWeekSummary,
        if (weightChangeKg != null) 'weightChangeKg': weightChangeKg,
        'decision': decision,
        if (source != null) 'source': source,
        if (generatedAt != null) 'generatedAt': generatedAt!.toIso8601String(),
        if (plan != null) 'plan': plan!.toJson(),
      };
}

class ReviewAdjustments {
  final int? sessionsPerWeek; // 1..7
  final int? sessionMinutes; // 5..90

  const ReviewAdjustments({
    this.sessionsPerWeek,
    this.sessionMinutes,
  });

  Map<String, dynamic> toJson() => {
        if (sessionsPerWeek != null) 'sessionsPerWeek': sessionsPerWeek,
        if (sessionMinutes != null) 'sessionMinutes': sessionMinutes,
      };
}

class ReviewDecisionRequest {
  final String decision; // accepted | adjusted
  final ReviewAdjustments? adjustments;

  const ReviewDecisionRequest({
    required this.decision,
    this.adjustments,
  });

  Map<String, dynamic> toJson() => {
        'decision': decision,
        if (adjustments != null) 'adjustments': adjustments!.toJson(),
      };
}
