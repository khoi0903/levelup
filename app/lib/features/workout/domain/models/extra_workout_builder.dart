import 'dart:math';

import '../../../onboarding/domain/models/plan_models.dart';
import 'exercise_response.dart';
import 'workout_session_state.dart';

/// Loại buổi tập gợi ý nhanh.
enum SuggestedWorkoutType {
  quick5('5 phút nhanh', 5, 'quick5'),
  light10('Bản nhẹ 10 phút', 10, 'light'),
  fullBody('Toàn thân', 15, 'normal'),
  legsGlutes('Chân & mông', 15, 'normal'),
  armsShoulders('Tay & vai', 15, 'normal'),
  coreAbs('Bụng (core)', 10, 'normal');

  const SuggestedWorkoutType(this.title, this.durationMin, this.variant);

  final String title;
  final int durationMin;
  final String variant;
}

/// Loại bỏ dấu tiếng Việt để tìm kiếm không dấu.
String removeVietnameseDiacritics(String str) {
  var result = str.toLowerCase();
  result = result.replaceAll(RegExp(r'[àáạảãâầấậẩẫăằắặẳẵ]'), 'a');
  result = result.replaceAll(RegExp(r'[èéẹẻẽêềếệểễ]'), 'e');
  result = result.replaceAll(RegExp(r'[ìíịỉĩ]'), 'i');
  result = result.replaceAll(RegExp(r'[òóọỏõôồốộổỗơờớợởỡ]'), 'o');
  result = result.replaceAll(RegExp(r'[ùúụủũưừứựửữ]'), 'u');
  result = result.replaceAll(RegExp(r'[ỳýỵỷỹ]'), 'y');
  result = result.replaceAll(RegExp(r'[đ]'), 'd');
  return result;
}

/// Lọc bài tập an toàn cho người dùng:
/// - Chỉ bài isActive
/// - Hợp nơi tập (home / gym): gym coi như đủ dụng cụ; home yêu cầu mọi dụng cụ của bài (trừ 'mat') nằm trong [userEquipment]
/// - Bỏ bài có contraindications trùng [activeInjuries]
List<ExerciseResponse> filterExercisesForUser({
  required List<ExerciseResponse> exercises,
  String? location,
  List<String> userEquipment = const [],
  List<String> activeInjuries = const [],
}) {
  final isGym = location == 'gym';
  final injurySet = activeInjuries.toSet();
  final equipSet = userEquipment.toSet();

  return exercises.where((e) {
    if (!e.isActive) return false;
    if (e.contraindications.any(injurySet.contains)) return false;
    if (isGym) return true;
    return e.equipment
        .where((eq) => eq != 'mat')
        .every(equipSet.contains);
  }).toList();
}

/// Ghép 3–5 bài tập từ danh sách bài đã lọc theo nhóm cơ của loại buổi gợi ý.
/// Mặc định 2–3 hiệp, số lần hoặc thời gian theo difficulty.
/// Nếu [isLowCheckin] == true: bớt 1 hiệp mỗi bài (tối thiểu 1) và ưu tiên bài difficulty thấp.
List<WorkoutPlanItem> buildSuggestedExercises({
  required List<ExerciseResponse> exercises,
  required SuggestedWorkoutType type,
  String? location,
  List<String> userEquipment = const [],
  List<String> activeInjuries = const [],
  bool isLowCheckin = false,
  int? durationMin,
}) {
  var available = filterExercisesForUser(
    exercises: exercises,
    location: location,
    userEquipment: userEquipment,
    activeInjuries: activeInjuries,
  );

  if (available.isEmpty) return const [];

  if (isLowCheckin) {
    available = List<ExerciseResponse>.from(available)
      ..sort((a, b) => (a.difficulty ?? 3).compareTo(b.difficulty ?? 3));
  }

  final List<ExerciseResponse> selected = [];

  switch (type) {
    case SuggestedWorkoutType.quick5:
      // Ưu tiên cardio, core, legs, chest
      final targetMuscles = {'cardio', 'core', 'legs', 'chest'};
      final primary = available.where((e) => targetMuscles.contains(e.primaryMuscle)).toList();
      selected.addAll(primary.take(3));
      if (selected.length < 3) {
        for (final e in available) {
          if (!selected.contains(e)) {
            selected.add(e);
            if (selected.length == 3) break;
          }
        }
      }
      break;

    case SuggestedWorkoutType.light10:
      final easy = available.where((e) => (e.difficulty ?? 1) <= 2).toList();
      final pool = easy.isNotEmpty
          ? easy
          : (List<ExerciseResponse>.from(available)
            ..sort((a, b) => (a.difficulty ?? 3).compareTo(b.difficulty ?? 3)));
      selected.addAll(pool.take(3));
      if (selected.length < 3) {
        for (final e in available) {
          if (!selected.contains(e)) {
            selected.add(e);
            if (selected.length == 3) break;
          }
        }
      }
      break;

    case SuggestedWorkoutType.legsGlutes:
      final targetMuscles = {'legs', 'glutes'};
      final primary = available.where((e) => targetMuscles.contains(e.primaryMuscle)).toList();
      selected.addAll(primary.take(5));
      if (selected.length < 3) {
        for (final e in available) {
          if (!selected.contains(e)) {
            selected.add(e);
            if (selected.length >= 3) break;
          }
        }
      }
      break;

    case SuggestedWorkoutType.armsShoulders:
      final targetMuscles = {'arms', 'shoulders', 'chest', 'back'};
      final primary = available.where((e) => targetMuscles.contains(e.primaryMuscle)).toList();
      selected.addAll(primary.take(5));
      if (selected.length < 3) {
        for (final e in available) {
          if (!selected.contains(e)) {
            selected.add(e);
            if (selected.length >= 3) break;
          }
        }
      }
      break;

    case SuggestedWorkoutType.coreAbs:
      final targetMuscles = {'core'};
      final primary = available.where((e) => targetMuscles.contains(e.primaryMuscle)).toList();
      selected.addAll(primary.take(5));
      if (selected.length < 3) {
        for (final e in available) {
          if (!selected.contains(e)) {
            selected.add(e);
            if (selected.length >= 3) break;
          }
        }
      }
      break;

    case SuggestedWorkoutType.fullBody:
      // Ghép đa dạng nhóm cơ: 1 legs/glutes, 1 chest/shoulders, 1 back/arms, 1 core/cardio
      final lower = available.where((e) => e.primaryMuscle == 'legs' || e.primaryMuscle == 'glutes').firstOrNull;
      final upperPush = available.where((e) => e.primaryMuscle == 'chest' || e.primaryMuscle == 'shoulders').firstOrNull;
      final upperPull = available.where((e) => e.primaryMuscle == 'back' || e.primaryMuscle == 'arms').firstOrNull;
      final coreOrCardio = available.where((e) => e.primaryMuscle == 'core' || e.primaryMuscle == 'cardio').firstOrNull;

      for (final e in [lower, upperPush, upperPull, coreOrCardio]) {
        if (e != null && !selected.contains(e)) selected.add(e);
      }

      // Nếu chưa đủ 3 bài, điền thêm từ available
      for (final e in available) {
        if (selected.length >= 4) break;
        if (!selected.contains(e)) selected.add(e);
      }
      break;
  }

  // Đảm bảo tối đa 5 bài, tối thiểu 3 bài nếu available >= 3
  final finalSelected = selected.take(min(5, max(3, selected.length))).toList();

  return finalSelected.map((e) {
    final diff = (e.difficulty == null || e.difficulty! <= 0) ? 3 : e.difficulty!;
    final isDuration = e.tracking == 'duration';

    final int sets;
    final int? reps;
    final int? durationSec;
    final int restSec;

    if (type == SuggestedWorkoutType.quick5) {
      const baseSets = 2;
      sets = isLowCheckin ? 1 : baseSets;
      reps = isDuration ? null : (6 + diff * 2);
      durationSec = isDuration ? (20 + diff * 5) : null;
      restSec = 20;
    } else if (type == SuggestedWorkoutType.light10) {
      sets = 2;
      reps = isDuration ? null : 8;
      durationSec = isDuration ? 20 : null;
      restSec = 30;
    } else {
      final baseSets = diff >= 3 ? 3 : 2;
      sets = isLowCheckin ? max(1, baseSets - 1) : baseSets;
      reps = isDuration ? null : (6 + diff * 2);
      durationSec = isDuration ? (20 + diff * 5) : null;
      restSec = diff >= 4 ? 45 : 30;
    }

    return WorkoutPlanItem(
      exerciseId: e.id,
      nameVi: e.nameVi,
      sets: sets,
      reps: reps,
      durationSec: durationSec,
      restSec: restSec,
      exercise: e,
    );
  }).toList();
}

String _localDateString(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String generateExtraWorkoutId() =>
    'extra-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';

/// Dựng WorkoutSetup cho buổi gợi ý.
WorkoutSetup buildSuggestedWorkoutSetup({
  required List<ExerciseResponse> exercises,
  required SuggestedWorkoutType type,
  String? location,
  List<String> userEquipment = const [],
  List<String> activeInjuries = const [],
  bool isLowCheckin = false,
  int? durationMin,
  String? id,
  DateTime? now,
}) {
  final items = buildSuggestedExercises(
    exercises: exercises,
    type: type,
    location: location,
    userEquipment: userEquipment,
    activeInjuries: activeInjuries,
    isLowCheckin: isLowCheckin,
    durationMin: durationMin,
  );

  final sessionId = id ?? generateExtraWorkoutId();
  final today = _localDateString(now ?? DateTime.now());
  final effectiveDuration = durationMin ?? type.durationMin;

  final session = SessionView(
    id: sessionId,
    title: type.title,
    scheduledDate: today,
    scheduledTime: '',
    durationMin: effectiveDuration,
    variant: isLowCheckin ? 'light' : type.variant,
    status: 'planned',
    items: items
        .map(
          (i) => ItemView(
            exerciseId: i.exerciseId,
            nameVi: i.nameVi,
            sets: i.sets,
            reps: i.reps,
            durationSec: i.durationSec,
            restSec: i.restSec,
          ),
        )
        .toList(),
  );

  return WorkoutSetup(session: session, items: items);
}

/// Dựng WorkoutSetup cho buổi tự chọn bài.
WorkoutSetup buildCustomWorkoutSetup({
  required List<WorkoutPlanItem> selectedItems,
  String? title,
  String? id,
  DateTime? now,
}) {
  final sessionId = id ?? generateExtraWorkoutId();
  final today = _localDateString(now ?? DateTime.now());
  final displayTitle = title ?? 'Tự chọn (${selectedItems.length} bài)';
  final estMin = max(5, selectedItems.length * 3);

  final session = SessionView(
    id: sessionId,
    title: displayTitle,
    scheduledDate: today,
    scheduledTime: '',
    durationMin: estMin,
    variant: 'normal',
    status: 'planned',
    items: selectedItems
        .map(
          (i) => ItemView(
            exerciseId: i.exerciseId,
            nameVi: i.nameVi,
            sets: i.sets,
            reps: i.reps,
            durationSec: i.durationSec,
            restSec: i.restSec,
          ),
        )
        .toList(),
  );

  return WorkoutSetup(session: session, items: selectedItems);
}

/// Dựng WorkoutSetup để tập lại buổi hôm nay đã hoàn thành.
WorkoutSetup buildRedoWorkoutSetup({
  required SessionView originalSession,
  required Map<String, ExerciseResponse> exercisesById,
  String? id,
  DateTime? now,
}) {
  final sessionId = id ?? generateExtraWorkoutId();
  final today = _localDateString(now ?? DateTime.now());

  final items = originalSession.items
      .map((i) => WorkoutPlanItem.from(i, exercisesById[i.exerciseId]))
      .toList();

  final session = SessionView(
    id: sessionId,
    title: '${originalSession.title} (tập lại)',
    scheduledDate: today,
    scheduledTime: '',
    durationMin: originalSession.durationMin,
    variant: originalSession.variant ?? 'normal',
    status: 'planned',
    items: originalSession.items,
  );

  return WorkoutSetup(session: session, items: items);
}
