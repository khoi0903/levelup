// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_database.dart';

// ignore_for_file: type=lint
class $WorkoutDraftsTable extends WorkoutDrafts
    with TableInfo<$WorkoutDraftsTable, WorkoutDraftEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientIdMeta = const VerificationMeta(
    'clientId',
  );
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
    'client_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stateJsonMeta = const VerificationMeta(
    'stateJson',
  );
  @override
  late final GeneratedColumn<String> stateJson = GeneratedColumn<String>(
    'state_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    clientId,
    sessionId,
    stateJson,
    updatedAt,
    status,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workout_drafts';
  @override
  VerificationContext validateIntegrity(
    Insertable<WorkoutDraftEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_id')) {
      context.handle(
        _clientIdMeta,
        clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta),
      );
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    }
    if (data.containsKey('state_json')) {
      context.handle(
        _stateJsonMeta,
        stateJson.isAcceptableOrUnknown(data['state_json']!, _stateJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_stateJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {clientId};
  @override
  WorkoutDraftEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WorkoutDraftEntry(
      clientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      ),
      stateJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
    );
  }

  @override
  $WorkoutDraftsTable createAlias(String alias) {
    return $WorkoutDraftsTable(attachedDatabase, alias);
  }
}

class WorkoutDraftEntry extends DataClass
    implements Insertable<WorkoutDraftEntry> {
  final String clientId;
  final String? sessionId;
  final String stateJson;
  final DateTime updatedAt;
  final String status;
  const WorkoutDraftEntry({
    required this.clientId,
    this.sessionId,
    required this.stateJson,
    required this.updatedAt,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_id'] = Variable<String>(clientId);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['state_json'] = Variable<String>(stateJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['status'] = Variable<String>(status);
    return map;
  }

  WorkoutDraftsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutDraftsCompanion(
      clientId: Value(clientId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      stateJson: Value(stateJson),
      updatedAt: Value(updatedAt),
      status: Value(status),
    );
  }

  factory WorkoutDraftEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WorkoutDraftEntry(
      clientId: serializer.fromJson<String>(json['clientId']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      stateJson: serializer.fromJson<String>(json['stateJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      status: serializer.fromJson<String>(json['status']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientId': serializer.toJson<String>(clientId),
      'sessionId': serializer.toJson<String?>(sessionId),
      'stateJson': serializer.toJson<String>(stateJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'status': serializer.toJson<String>(status),
    };
  }

  WorkoutDraftEntry copyWith({
    String? clientId,
    Value<String?> sessionId = const Value.absent(),
    String? stateJson,
    DateTime? updatedAt,
    String? status,
  }) => WorkoutDraftEntry(
    clientId: clientId ?? this.clientId,
    sessionId: sessionId.present ? sessionId.value : this.sessionId,
    stateJson: stateJson ?? this.stateJson,
    updatedAt: updatedAt ?? this.updatedAt,
    status: status ?? this.status,
  );
  WorkoutDraftEntry copyWithCompanion(WorkoutDraftsCompanion data) {
    return WorkoutDraftEntry(
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      stateJson: data.stateJson.present ? data.stateJson.value : this.stateJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutDraftEntry(')
          ..write('clientId: $clientId, ')
          ..write('sessionId: $sessionId, ')
          ..write('stateJson: $stateJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(clientId, sessionId, stateJson, updatedAt, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WorkoutDraftEntry &&
          other.clientId == this.clientId &&
          other.sessionId == this.sessionId &&
          other.stateJson == this.stateJson &&
          other.updatedAt == this.updatedAt &&
          other.status == this.status);
}

class WorkoutDraftsCompanion extends UpdateCompanion<WorkoutDraftEntry> {
  final Value<String> clientId;
  final Value<String?> sessionId;
  final Value<String> stateJson;
  final Value<DateTime> updatedAt;
  final Value<String> status;
  final Value<int> rowid;
  const WorkoutDraftsCompanion({
    this.clientId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.stateJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutDraftsCompanion.insert({
    required String clientId,
    this.sessionId = const Value.absent(),
    required String stateJson,
    required DateTime updatedAt,
    required String status,
    this.rowid = const Value.absent(),
  }) : clientId = Value(clientId),
       stateJson = Value(stateJson),
       updatedAt = Value(updatedAt),
       status = Value(status);
  static Insertable<WorkoutDraftEntry> custom({
    Expression<String>? clientId,
    Expression<String>? sessionId,
    Expression<String>? stateJson,
    Expression<DateTime>? updatedAt,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientId != null) 'client_id': clientId,
      if (sessionId != null) 'session_id': sessionId,
      if (stateJson != null) 'state_json': stateJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutDraftsCompanion copyWith({
    Value<String>? clientId,
    Value<String?>? sessionId,
    Value<String>? stateJson,
    Value<DateTime>? updatedAt,
    Value<String>? status,
    Value<int>? rowid,
  }) {
    return WorkoutDraftsCompanion(
      clientId: clientId ?? this.clientId,
      sessionId: sessionId ?? this.sessionId,
      stateJson: stateJson ?? this.stateJson,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (stateJson.present) {
      map['state_json'] = Variable<String>(stateJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutDraftsCompanion(')
          ..write('clientId: $clientId, ')
          ..write('sessionId: $sessionId, ')
          ..write('stateJson: $stateJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$WorkoutDatabase extends GeneratedDatabase {
  _$WorkoutDatabase(QueryExecutor e) : super(e);
  $WorkoutDatabaseManager get managers => $WorkoutDatabaseManager(this);
  late final $WorkoutDraftsTable workoutDrafts = $WorkoutDraftsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [workoutDrafts];
}

typedef $$WorkoutDraftsTableCreateCompanionBuilder =
    WorkoutDraftsCompanion Function({
      required String clientId,
      Value<String?> sessionId,
      required String stateJson,
      required DateTime updatedAt,
      required String status,
      Value<int> rowid,
    });
typedef $$WorkoutDraftsTableUpdateCompanionBuilder =
    WorkoutDraftsCompanion Function({
      Value<String> clientId,
      Value<String?> sessionId,
      Value<String> stateJson,
      Value<DateTime> updatedAt,
      Value<String> status,
      Value<int> rowid,
    });

class $$WorkoutDraftsTableFilterComposer
    extends Composer<_$WorkoutDatabase, $WorkoutDraftsTable> {
  $$WorkoutDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WorkoutDraftsTableOrderingComposer
    extends Composer<_$WorkoutDatabase, $WorkoutDraftsTable> {
  $$WorkoutDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientId => $composableBuilder(
    column: $table.clientId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stateJson => $composableBuilder(
    column: $table.stateJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WorkoutDraftsTableAnnotationComposer
    extends Composer<_$WorkoutDatabase, $WorkoutDraftsTable> {
  $$WorkoutDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get stateJson =>
      $composableBuilder(column: $table.stateJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);
}

class $$WorkoutDraftsTableTableManager
    extends
        RootTableManager<
          _$WorkoutDatabase,
          $WorkoutDraftsTable,
          WorkoutDraftEntry,
          $$WorkoutDraftsTableFilterComposer,
          $$WorkoutDraftsTableOrderingComposer,
          $$WorkoutDraftsTableAnnotationComposer,
          $$WorkoutDraftsTableCreateCompanionBuilder,
          $$WorkoutDraftsTableUpdateCompanionBuilder,
          (
            WorkoutDraftEntry,
            BaseReferences<
              _$WorkoutDatabase,
              $WorkoutDraftsTable,
              WorkoutDraftEntry
            >,
          ),
          WorkoutDraftEntry,
          PrefetchHooks Function()
        > {
  $$WorkoutDraftsTableTableManager(
    _$WorkoutDatabase db,
    $WorkoutDraftsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> clientId = const Value.absent(),
                Value<String?> sessionId = const Value.absent(),
                Value<String> stateJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WorkoutDraftsCompanion(
                clientId: clientId,
                sessionId: sessionId,
                stateJson: stateJson,
                updatedAt: updatedAt,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String clientId,
                Value<String?> sessionId = const Value.absent(),
                required String stateJson,
                required DateTime updatedAt,
                required String status,
                Value<int> rowid = const Value.absent(),
              }) => WorkoutDraftsCompanion.insert(
                clientId: clientId,
                sessionId: sessionId,
                stateJson: stateJson,
                updatedAt: updatedAt,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WorkoutDraftsTable, WorkoutDraftEntry>(table),
                  BaseReferences<
                    _$WorkoutDatabase,
                    $WorkoutDraftsTable,
                    WorkoutDraftEntry
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WorkoutDraftsTableProcessedTableManager =
    ProcessedTableManager<
      _$WorkoutDatabase,
      $WorkoutDraftsTable,
      WorkoutDraftEntry,
      $$WorkoutDraftsTableFilterComposer,
      $$WorkoutDraftsTableOrderingComposer,
      $$WorkoutDraftsTableAnnotationComposer,
      $$WorkoutDraftsTableCreateCompanionBuilder,
      $$WorkoutDraftsTableUpdateCompanionBuilder,
      (
        WorkoutDraftEntry,
        BaseReferences<
          _$WorkoutDatabase,
          $WorkoutDraftsTable,
          WorkoutDraftEntry
        >,
      ),
      WorkoutDraftEntry,
      PrefetchHooks Function()
    >;

class $WorkoutDatabaseManager {
  final _$WorkoutDatabase _db;
  $WorkoutDatabaseManager(this._db);
  $$WorkoutDraftsTableTableManager get workoutDrafts =>
      $$WorkoutDraftsTableTableManager(_db, _db.workoutDrafts);
}
