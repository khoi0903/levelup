import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'workout_database.g.dart';

@DataClassName('WorkoutDraftEntry')
class WorkoutDrafts extends Table {
  TextColumn get clientId => text()();
  TextColumn get sessionId => text().nullable()();
  TextColumn get stateJson => text()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get status => text()(); // 'active' | 'pending_submit'

  @override
  Set<Column> get primaryKey => {clientId};
}

@DriftDatabase(tables: [WorkoutDrafts])
class WorkoutDatabase extends _$WorkoutDatabase {
  WorkoutDatabase([QueryExecutor? e])
      : super(e ?? driftDatabase(name: 'workout_drafts')) {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  }

  @override
  int get schemaVersion => 1;
}
