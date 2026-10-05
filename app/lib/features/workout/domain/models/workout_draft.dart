import 'dart:convert';

import 'workout_models.dart';
import 'workout_session_state.dart';

class WorkoutDraft {
  final String clientId;
  final String? sessionId;
  final String stateJson;
  final DateTime updatedAt;
  final String status; // 'active' | 'pending_submit'

  const WorkoutDraft({
    required this.clientId,
    this.sessionId,
    required this.stateJson,
    required this.updatedAt,
    required this.status,
  });

  bool get isActive => status == 'active';
  bool get isPendingSubmit => status == 'pending_submit';

  bool isExpired(
    DateTime now, {
    Duration maxAge = const Duration(hours: 12),
  }) {
    return now.difference(updatedAt) > maxAge;
  }

  WorkoutSessionState get sessionState {
    final map = jsonDecode(stateJson) as Map<String, dynamic>;
    if (map.containsKey('sessionState')) {
      return WorkoutSessionState.fromJson(
        map['sessionState'] as Map<String, dynamic>,
      );
    }
    return WorkoutSessionState.fromJson(map);
  }

  int? get rpe {
    final map = jsonDecode(stateJson) as Map<String, dynamic>;
    return (map['rpe'] as num?)?.toInt();
  }

  List<PainArea> get painAreas {
    final map = jsonDecode(stateJson) as Map<String, dynamic>;
    final list = map['painAreas'] as List<dynamic>?;
    if (list == null) return const [];
    return list
        .map(
          (p) => PainArea.values.firstWhere(
            (a) => a.json == p,
            orElse: () => PainArea.other,
          ),
        )
        .toList();
  }

  String? get note {
    final map = jsonDecode(stateJson) as Map<String, dynamic>;
    return map['note'] as String?;
  }

  WorkoutRequest toWorkoutRequest({DateTime? fallbackEndedAt}) {
    final s = sessionState;
    return WorkoutRequest(
      clientId: s.clientId,
      plannedSessionId: s.plannedSessionId,
      startedAt: s.startedAt,
      endedAt: s.endedAt ?? fallbackEndedAt ?? updatedAt,
      variant: s.variant,
      rpe: rpe,
      painAreas: painAreas,
      note: note,
      sets: s.sets,
    );
  }

  static String encodeStateJson(
    WorkoutSessionState state, {
    int? rpe,
    List<PainArea> painAreas = const [],
    String? note,
  }) {
    return jsonEncode({
      'sessionState': state.toJson(),
      'rpe': ?rpe,
      if (painAreas.isNotEmpty)
        'painAreas': painAreas.map((p) => p.json).toList(),
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }
}
