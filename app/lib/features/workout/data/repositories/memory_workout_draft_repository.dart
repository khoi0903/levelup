import '../../domain/models/workout_draft.dart';
import '../../domain/repositories/workout_draft_repository.dart';

class MemoryWorkoutDraftRepository implements WorkoutDraftRepository {
  final Map<String, WorkoutDraft> _drafts = {};

  MemoryWorkoutDraftRepository([List<WorkoutDraft> initialDrafts = const []]) {
    for (final d in initialDrafts) {
      _drafts[d.clientId] = d;
    }
  }

  @override
  Future<void> saveDraft(WorkoutDraft draft) async {
    _drafts[draft.clientId] = draft;
  }

  @override
  Future<WorkoutDraft?> getDraft(String clientId) async {
    return _drafts[clientId];
  }

  @override
  Future<WorkoutDraft?> getActiveDraft() async {
    final active = _drafts.values.where((d) => d.isActive).toList();
    if (active.isEmpty) return null;
    active.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return active.first;
  }

  @override
  Future<List<WorkoutDraft>> getPendingSubmitDrafts() async {
    final pending = _drafts.values.where((d) => d.isPendingSubmit).toList();
    pending.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
    return pending;
  }

  @override
  Future<List<WorkoutDraft>> getAllDrafts() async {
    final all = _drafts.values.toList();
    all.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return all;
  }

  @override
  Future<void> updateStatus(String clientId, String status) async {
    final existing = _drafts[clientId];
    if (existing != null) {
      _drafts[clientId] = WorkoutDraft(
        clientId: existing.clientId,
        sessionId: existing.sessionId,
        stateJson: existing.stateJson,
        updatedAt: DateTime.now(),
        status: status,
      );
    }
  }

  @override
  Future<void> deleteDraft(String clientId) async {
    _drafts.remove(clientId);
  }

  @override
  Future<int> deleteExpiredDrafts(
    DateTime now, {
    Duration maxAge = const Duration(hours: 12),
  }) async {
    final expiredKeys = _drafts.entries
        .where((e) => e.value.isExpired(now, maxAge: maxAge))
        .map((e) => e.key)
        .toList();
    for (final k in expiredKeys) {
      _drafts.remove(k);
    }
    return expiredKeys.length;
  }

  @override
  Future<void> deleteAllDrafts() async {
    _drafts.clear();
  }
}
