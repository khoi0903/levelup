import 'dart:math';

import '../../../../core/api/api_exceptions.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import 'exercise_response.dart';
import 'workout_models.dart';

/// Cách ghi một bài: theo số lần, số lần + tạ, hoặc theo thời gian.
enum TrackingMode { reps, repsWeight, duration }

/// Một bài trong buổi, ghép ItemView của kế hoạch với ExerciseResponse.
class WorkoutPlanItem {
  final String exerciseId;
  final String nameVi;
  final int sets;
  final int? reps;
  final int? durationSec;
  final int restSec;
  final ExerciseResponse? exercise;

  const WorkoutPlanItem({
    required this.exerciseId,
    required this.nameVi,
    required this.sets,
    this.reps,
    this.durationSec,
    this.restSec = 0,
    this.exercise,
  });

  factory WorkoutPlanItem.from(ItemView item, ExerciseResponse? exercise) =>
      WorkoutPlanItem(
        exerciseId: item.exerciseId,
        nameVi: item.nameVi ?? exercise?.nameVi ?? 'Bài tập',
        sets: max(1, item.sets ?? 1),
        reps: item.reps,
        durationSec: item.durationSec,
        restSec: max(0, item.restSec ?? 0),
        exercise: exercise,
      );

  TrackingMode get tracking {
    switch (exercise?.tracking) {
      case 'duration':
        return TrackingMode.duration;
      case 'reps_weight':
        return TrackingMode.repsWeight;
      case 'reps':
        return TrackingMode.reps;
    }
    return durationSec != null && reps == null
        ? TrackingMode.duration
        : TrackingMode.reps;
  }

  /// "3 hiệp × 12 lần" hoặc "2 hiệp × 30 giây".
  String get targetLabel {
    final per = tracking == TrackingMode.duration
        ? '${durationSec ?? 30} giây'
        : '${reps ?? 10} lần';
    return '$sets hiệp × $per';
  }
}

/// Dữ liệu để mở một buổi: buổi trong kế hoạch và các bài đã ghép.
class WorkoutSetup {
  final SessionView session;
  final List<WorkoutPlanItem> items;

  const WorkoutSetup({required this.session, required this.items});
}

/// Buổi tập đang diễn ra, giữ trong bộ nhớ tới khi gửi thành công.
class WorkoutSessionState {
  final SessionView session;
  final List<WorkoutPlanItem> items;
  final String clientId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int exerciseIndex;

  /// Hiệp đang tập của bài hiện tại, bắt đầu từ 1.
  final int setNumber;
  final List<SetLog> sets;
  final bool submitting;
  final WorkoutResult? result;
  final ApiException? error;

  const WorkoutSessionState({
    required this.session,
    required this.items,
    required this.clientId,
    required this.startedAt,
    this.endedAt,
    this.exerciseIndex = 0,
    this.setNumber = 1,
    this.sets = const [],
    this.submitting = false,
    this.result,
    this.error,
  });

  static const _variants = {'normal', 'light', 'quick5', 'advanced'};
  static final _objectId = RegExp(r'^[0-9a-f]{24}$');

  String get variant =>
      _variants.contains(session.variant) ? session.variant! : 'normal';

  /// Backend chỉ nhận ObjectId; id giả (dữ liệu demo) thì bỏ qua.
  String? get plannedSessionId =>
      _objectId.hasMatch(session.id) ? session.id : null;

  bool get allExercisesDone => exerciseIndex >= items.length;

  WorkoutPlanItem? get currentItem =>
      allExercisesDone ? null : items[exerciseIndex];

  /// Tạ của hiệp gần nhất cùng bài, để điền sẵn.
  double? lastWeightFor(String exerciseId) {
    for (final s in sets.reversed) {
      if (s.exerciseId == exerciseId && s.weightKg != null) return s.weightKg;
    }
    return null;
  }

  int setsDoneFor(String exerciseId) =>
      sets.where((s) => s.exerciseId == exerciseId).length;

  WorkoutSessionState copyWith({
    DateTime? endedAt,
    int? exerciseIndex,
    int? setNumber,
    List<SetLog>? sets,
    bool? submitting,
    WorkoutResult? result,
    ApiException? error,
    bool clearError = false,
  }) =>
      WorkoutSessionState(
        session: session,
        items: items,
        clientId: clientId,
        startedAt: startedAt,
        endedAt: endedAt ?? this.endedAt,
        exerciseIndex: exerciseIndex ?? this.exerciseIndex,
        setNumber: setNumber ?? this.setNumber,
        sets: sets ?? this.sets,
        submitting: submitting ?? this.submitting,
        result: result ?? this.result,
        error: clearError ? null : (error ?? this.error),
      );
}
