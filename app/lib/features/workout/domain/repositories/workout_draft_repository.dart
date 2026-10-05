import '../models/workout_draft.dart';

abstract class WorkoutDraftRepository {
  Future<void> saveDraft(WorkoutDraft draft);
  Future<WorkoutDraft?> getDraft(String clientId);
  Future<WorkoutDraft?> getActiveDraft();
  Future<List<WorkoutDraft>> getPendingSubmitDrafts();
  Future<List<WorkoutDraft>> getAllDrafts();
  Future<void> updateStatus(String clientId, String status);
  Future<void> deleteDraft(String clientId);
  Future<int> deleteExpiredDrafts(
    DateTime now, {
    Duration maxAge = const Duration(hours: 12),
  });
  Future<void> deleteAllDrafts();
}
