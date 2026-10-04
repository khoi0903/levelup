import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../../onboarding/presentation/controllers/onboarding_controller.dart';
import '../../data/camera/camera_permission.dart';
import '../../data/camera/camera_setup_skip.dart';
import '../../data/camera/rep_counting_session.dart';
import '../../data/repositories/api_workout_repository.dart';
import '../../domain/models/exercise_response.dart';
import '../../domain/models/workout_models.dart';
import '../../domain/models/workout_session_state.dart';
import '../../domain/repositories/workout_repository.dart';

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return ApiWorkoutRepository(ref.watch(apiClientProvider));
});

final repSessionFactoryProvider = Provider<RepSessionFactory>((ref) {
  return const CameraRepSessionFactory();
});

final cameraPermissionProvider = Provider<CameraPermissionGate>((ref) {
  return const PlatformCameraPermissionGate();
});

/// "Không hỏi lại hôm nay" ở màn Đặt camera.
final cameraSetupSkipProvider = Provider<CameraSetupSkip>((ref) {
  return const PrefsCameraSetupSkip();
});

/// Đồng hồ cho buổi tập; test ghi đè để cố định thời gian.
final workoutClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final clientIdGeneratorProvider = Provider<String Function()>((ref) {
  return generateClientId;
});

const _idAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// 24 ký tự [A-Za-z0-9], khớp regex clientId của backend ([A-Za-z0-9_-]{8,64}).
String generateClientId() {
  final random = Random.secure();
  return List.generate(
    24,
    (_) => _idAlphabet[random.nextInt(_idAlphabet.length)],
  ).join();
}

String localDateString(DateTime now) =>
    '${now.year.toString().padLeft(4, '0')}-'
    '${now.month.toString().padLeft(2, '0')}-'
    '${now.day.toString().padLeft(2, '0')}';

bool isSessionOpen(SessionView s) =>
    s.status != 'completed' && s.status != 'rest' && s.status != 'missed';

/// Buổi nên tập tiếp: buổi còn mở sớm nhất từ hôm nay trở đi, nếu không có
/// thì buổi còn mở đầu tiên, cuối cùng là buổi đầu tiên.
SessionView? pickNextSession(PlanView plan, String today) {
  final open = plan.sessions.where(isSessionOpen).toList();
  final upcoming = open.where((s) => s.scheduledDate.compareTo(today) >= 0);
  if (upcoming.isNotEmpty) return upcoming.first;
  if (open.isNotEmpty) return open.first;
  return plan.sessions.isNotEmpty ? plan.sessions.first : null;
}

typedef WorkoutSetupArgs = ({String? sessionId, bool quick5});

/// Tải kế hoạch + thư viện bài tập và ghép thành buổi để tập.
final workoutSetupProvider = FutureProvider.autoDispose
    .family<WorkoutSetup, WorkoutSetupArgs>((ref, args) async {
      final workoutRepo = ref.watch(workoutRepositoryProvider);
      final planRepo = ref.watch(planRepositoryProvider);
      final now = ref.watch(workoutClockProvider)();

      final exercisesFuture = workoutRepo.getExercises();
      var plan = await planRepo.getCurrentPlan();
      SessionView? session = args.sessionId == null
          ? pickNextSession(plan, localDateString(now))
          : plan.sessions.where((s) => s.id == args.sessionId).firstOrNull;
      if (session == null) {
        throw const ApiException(code: 'SESSION_NOT_FOUND', statusCode: 404);
      }
      if (args.quick5 &&
          session.variant != 'quick5' &&
          isSessionOpen(session)) {
        plan = await workoutRepo.makeQuick5(session.id);
        final id = session.id;
        session = plan.sessions.firstWhere(
          (s) => s.id == id,
          orElse: () => session!,
        );
      }

      final exercises = <String, ExerciseResponse>{
        for (final e in await exercisesFuture) e.id: e,
      };
      return WorkoutSetup(
        session: session,
        items: session.items
            .map((i) => WorkoutPlanItem.from(i, exercises[i.exerciseId]))
            .toList(),
      );
    });

/// Buổi đang tập. Không autoDispose: giữ cả clientId để gửi lại khi lỗi mạng.
// TODO(app): lưu bản nháp xuống drift (AGENTS.md) để còn giữ khi app bị tắt;
// pubspec chưa có drift/path_provider nên hiện chỉ giữ trong bộ nhớ.
final activeWorkoutProvider =
    StateNotifierProvider<WorkoutController, WorkoutSessionState?>((ref) {
      return WorkoutController(ref);
    });

class WorkoutController extends StateNotifier<WorkoutSessionState?> {
  WorkoutController(this._ref) : super(null);

  final Ref _ref;

  DateTime _now() => _ref.read(workoutClockProvider)();

  void start(WorkoutSetup setup) {
    state = WorkoutSessionState(
      session: setup.session,
      items: setup.items,
      clientId: _ref.read(clientIdGeneratorProvider)(),
      startedAt: _now(),
    );
  }

  /// Ghi hiệp vừa xong của bài hiện tại rồi chuyển hiệp/bài.
  /// Trả số giây nghỉ trước hiệp kế tiếp (0 nếu không cần nghỉ hoặc đã hết bài).
  int logSet(SetLog set) {
    final s = state;
    final item = s?.currentItem;
    if (s == null || item == null) return 0;
    final logged = set.withSetIndex(s.setNumber);
    final sets = [...s.sets, logged];
    if (s.setNumber < item.sets) {
      state = s.copyWith(sets: sets, setNumber: s.setNumber + 1);
      return item.restSec;
    }
    state = s.copyWith(
      sets: sets,
      exerciseIndex: s.exerciseIndex + 1,
      setNumber: 1,
    );
    return state!.allExercisesDone ? 0 : item.restSec;
  }

  void skipExercise() {
    final s = state;
    if (s == null || s.allExercisesDone) return;
    state = s.copyWith(exerciseIndex: s.exerciseIndex + 1, setNumber: 1);
  }

  /// Chốt giờ kết thúc một lần; gửi lại vẫn dùng đúng giờ này.
  void finish() {
    final s = state;
    if (s == null || s.endedAt != null) return;
    state = s.copyWith(endedAt: _now());
  }

  WorkoutRequest? buildRequest({
    int? rpe,
    List<PainArea> painAreas = const [],
    String? note,
  }) {
    final s = state;
    if (s == null) return null;
    return WorkoutRequest(
      clientId: s.clientId,
      plannedSessionId: s.plannedSessionId,
      startedAt: s.startedAt,
      endedAt: s.endedAt ?? _now(),
      variant: s.variant,
      rpe: rpe,
      painAreas: painAreas,
      note: note,
      sets: s.sets,
    );
  }

  /// Gửi POST /workouts. Lỗi thì giữ nguyên buổi (cùng clientId) để thử lại.
  Future<WorkoutResult?> submit({
    int? rpe,
    List<PainArea> painAreas = const [],
    String? note,
  }) async {
    finish();
    final request = buildRequest(rpe: rpe, painAreas: painAreas, note: note);
    if (request == null || state!.submitting) return null;
    if (state!.result != null) return state!.result;
    state = state!.copyWith(submitting: true, clearError: true);
    try {
      final result = await _ref
          .read(workoutRepositoryProvider)
          .saveWorkout(request);
      if (!mounted || state == null) return result;
      state = state!.copyWith(submitting: false, result: result);
      return result;
    } on ApiException catch (e) {
      if (mounted && state != null) {
        state = state!.copyWith(submitting: false, error: e);
      }
      return null;
    } catch (_) {
      if (mounted && state != null) {
        state = state!.copyWith(
          submitting: false,
          error: const ApiException(code: 'UNKNOWN_ERROR'),
        );
      }
      return null;
    }
  }

  void clear() => state = null;
}
