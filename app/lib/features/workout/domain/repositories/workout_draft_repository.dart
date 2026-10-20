import '../models/workout_draft.dart';

abstract class WorkoutDraftRepository {
  Future<void> saveDraft(WorkoutDraft draft);
  Future<WorkoutDraft?> getDraft(String clientId);
  Future<WorkoutDraft?> getActiveDraft();
  Future<List<WorkoutDraft>> getPendingSubmitDrafts();
  Future<List<WorkoutDraft>> getAllDrafts();
  Future<void> updateStatus(String clientId, String status);
  Future<void> deleteDraft(String clientId);

  /// Xóa buổi đang tập dở (active) quá [maxAge]. Buổi đã tập xong nhưng chưa gửi được
  /// (pending_submit) giữ lại để gửi sau, chỉ xóa khi quá [pendingMaxAge].
  Future<int> deleteExpiredDrafts(
    DateTime now, {
    Duration maxAge = const Duration(hours: 12),
    Duration pendingMaxAge = WorkoutDraft.pendingMaxAge,
  });
  Future<void> deleteAllDrafts();
}
