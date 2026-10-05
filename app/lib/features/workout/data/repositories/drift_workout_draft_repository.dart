import 'package:drift/drift.dart';

import '../../domain/models/workout_draft.dart';
import '../../domain/repositories/workout_draft_repository.dart';
import '../local/workout_database.dart';
import 'memory_workout_draft_repository.dart';

class DriftWorkoutDraftRepository implements WorkoutDraftRepository {
  final WorkoutDatabase _db;
  final MemoryWorkoutDraftRepository _memoryFallback =
      MemoryWorkoutDraftRepository();
  bool _useFallback = false;

  DriftWorkoutDraftRepository(this._db);

  WorkoutDraft _toDomain(WorkoutDraftEntry entry) => WorkoutDraft(
        clientId: entry.clientId,
        sessionId: entry.sessionId,
        stateJson: entry.stateJson,
        updatedAt: entry.updatedAt,
        status: entry.status,
      );

  @override
  Future<void> saveDraft(WorkoutDraft draft) async {
    if (_useFallback) return _memoryFallback.saveDraft(draft);
    try {
      await _db.into(_db.workoutDrafts).insertOnConflictUpdate(
            WorkoutDraftsCompanion.insert(
              clientId: draft.clientId,
              sessionId: Value(draft.sessionId),
              stateJson: draft.stateJson,
              updatedAt: draft.updatedAt,
              status: draft.status,
            ),
          );
    } catch (_) {
      _useFallback = true;
      return _memoryFallback.saveDraft(draft);
    }
  }

  @override
  Future<WorkoutDraft?> getDraft(String clientId) async {
    if (_useFallback) return _memoryFallback.getDraft(clientId);
    try {
      final query = _db.select(_db.workoutDrafts)
        ..where((tbl) => tbl.clientId.equals(clientId));
      final entry = await query.getSingleOrNull();
      return entry != null ? _toDomain(entry) : null;
    } catch (_) {
      _useFallback = true;
      return _memoryFallback.getDraft(clientId);
    }
  }

  @override
  Future<WorkoutDraft?> getActiveDraft() async {
    if (_useFallback) return _memoryFallback.getActiveDraft();
    try {
      final query = _db.select(_db.workoutDrafts)
        ..where((tbl) => tbl.status.equals('active'))
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)])
        ..limit(1);
      final entry = await query.getSingleOrNull();
      return entry != null ? _toDomain(entry) : null;
    } catch (_) {
      _useFallback = true;
      return _memoryFallback.getActiveDraft();
    }
  }

  @override
  Future<List<WorkoutDraft>> getPendingSubmitDrafts() async {
    if (_useFallback) return _memoryFallback.getPendingSubmitDrafts();
    try {
      final query = _db.select(_db.workoutDrafts)
        ..where((tbl) => tbl.status.equals('pending_submit'))
        ..orderBy([(tbl) => OrderingTerm.asc(tbl.updatedAt)]);
      final entries = await query.get();
      return entries.map(_toDomain).toList();
    } catch (_) {
      _useFallback = true;
      return _memoryFallback.getPendingSubmitDrafts();
    }
  }

  @override
  Future<List<WorkoutDraft>> getAllDrafts() async {
    if (_useFallback) return _memoryFallback.getAllDrafts();
    try {
      final query = _db.select(_db.workoutDrafts)
        ..orderBy([(tbl) => OrderingTerm.desc(tbl.updatedAt)]);
      final entries = await query.get();
      return entries.map(_toDomain).toList();
    } catch (_) {
      _useFallback = true;
      return _memoryFallback.getAllDrafts();
    }
  }

  @override
  Future<void> updateStatus(String clientId, String status) async {
    if (_useFallback) return _memoryFallback.updateStatus(clientId, status);
    try {
      await (_db.update(_db.workoutDrafts)
            ..where((tbl) => tbl.clientId.equals(clientId)))
          .write(
        WorkoutDraftsCompanion(
          status: Value(status),
          updatedAt: Value(DateTime.now()),
        ),
      );
    } catch (_) {
      _useFallback = true;
      return _memoryFallback.updateStatus(clientId, status);
    }
  }

  @override
  Future<void> deleteDraft(String clientId) async {
    if (_useFallback) return _memoryFallback.deleteDraft(clientId);
    try {
      await (_db.delete(_db.workoutDrafts)
            ..where((tbl) => tbl.clientId.equals(clientId)))
          .go();
    } catch (_) {
      _useFallback = true;
      return _memoryFallback.deleteDraft(clientId);
    }
  }

  @override
  Future<int> deleteExpiredDrafts(
    DateTime now, {
    Duration maxAge = const Duration(hours: 12),
  }) async {
    if (_useFallback) {
      return _memoryFallback.deleteExpiredDrafts(now, maxAge: maxAge);
    }
    try {
      final threshold = now.subtract(maxAge);
      return await (_db.delete(_db.workoutDrafts)
            ..where((tbl) => tbl.updatedAt.isSmallerThanValue(threshold)))
          .go();
    } catch (_) {
      _useFallback = true;
      return _memoryFallback.deleteExpiredDrafts(now, maxAge: maxAge);
    }
  }

  @override
  Future<void> deleteAllDrafts() async {
    if (_useFallback) return _memoryFallback.deleteAllDrafts();
    try {
      await _db.delete(_db.workoutDrafts).go();
    } catch (_) {
      _useFallback = true;
      return _memoryFallback.deleteAllDrafts();
    }
  }
}
