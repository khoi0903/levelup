import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../../../onboarding/domain/models/plan_models.dart';
import '../../data/repositories/api_skip_report_repository.dart';
import '../../domain/models/skip_report_models.dart';
import '../../domain/repositories/skip_report_repository.dart';

final skipReportRepositoryProvider = Provider<SkipReportRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return ApiSkipReportRepository(client: client);
});

class SkipReportState {
  final String? plannedSessionId;
  final String reason;
  final String? note;
  final String? bodyArea;
  final bool isSubmitting;
  final SkipReportResponse? response;
  final PlanView? patchedPlan;
  final dynamic error;

  const SkipReportState({
    this.plannedSessionId,
    this.reason = 'busy',
    this.note,
    this.bodyArea,
    this.isSubmitting = false,
    this.response,
    this.patchedPlan,
    this.error,
  });

  SkipReportState copyWith({
    String? plannedSessionId,
    String? reason,
    String? note,
    String? bodyArea,
    bool? isSubmitting,
    SkipReportResponse? response,
    PlanView? patchedPlan,
    dynamic error,
    bool clearError = false,
  }) {
    return SkipReportState(
      plannedSessionId: plannedSessionId ?? this.plannedSessionId,
      reason: reason ?? this.reason,
      note: note ?? this.note,
      bodyArea: bodyArea ?? this.bodyArea,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      response: response ?? this.response,
      patchedPlan: patchedPlan ?? this.patchedPlan,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SkipReportNotifier extends StateNotifier<SkipReportState> {
  final SkipReportRepository _repository;

  SkipReportNotifier(this._repository, {String? sessionId})
    : super(SkipReportState(plannedSessionId: sessionId));

  void setReason(String reason) {
    state = state.copyWith(reason: reason, clearError: true);
  }

  void setBodyArea(String? bodyArea) {
    state = state.copyWith(bodyArea: bodyArea, clearError: true);
  }

  void setNote(String? note) {
    state = state.copyWith(note: note, clearError: true);
  }

  Future<SkipReportResponse?> submitReport() async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final req = SkipReportRequest(
        plannedSessionId: state.plannedSessionId,
        reason: state.reason,
        note: state.note,
        bodyArea: state.reason == 'pain' ? state.bodyArea : null,
      );
      final res = await _repository.reportSkip(req);
      state = state.copyWith(isSubmitting: false, response: res);
      return res;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
      return null;
    }
  }

  Future<PlanView?> restSession({required String sessionId}) async {
    state = state.copyWith(isSubmitting: true, clearError: true);
    try {
      final req = const PatchSessionRequest(action: 'rest');
      final res = await _repository.patchSession(sessionId, req);
      state = state.copyWith(isSubmitting: false, patchedPlan: res);
      return res;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e);
      return null;
    }
  }
}

final skipReportControllerProvider = StateNotifierProvider.autoDispose
    .family<SkipReportNotifier, SkipReportState, String?>((ref, sessionId) {
      final repo = ref.watch(skipReportRepositoryProvider);
      return SkipReportNotifier(repo, sessionId: sessionId);
    });
