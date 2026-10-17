class ActivitySyncRequest {
  final String localDate;
  final int steps;
  final int activeKcal;

  const ActivitySyncRequest({
    required this.localDate,
    required this.steps,
    required this.activeKcal,
  });

  Map<String, dynamic> toJson() => {
    'localDate': localDate,
    'steps': steps,
    'activeKcal': activeKcal,
  };
}

class ActivitySyncResponse {
  final String localDate;
  final int steps;
  final int activeKcal;
  final bool stored;

  const ActivitySyncResponse({
    required this.localDate,
    required this.steps,
    required this.activeKcal,
    required this.stored,
  });

  factory ActivitySyncResponse.fromJson(Map<String, dynamic> json) =>
      ActivitySyncResponse(
        localDate: json['localDate'] as String? ?? '',
        steps: (json['steps'] as num?)?.toInt() ?? 0,
        activeKcal: (json['activeKcal'] as num?)?.toInt() ?? 0,
        stored: json['stored'] as bool? ?? false,
      );
}
