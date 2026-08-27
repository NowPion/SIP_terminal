// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_db.dart';

// ignore_for_file: type=lint
class $LocalCallsTable extends LocalCalls
    with TableInfo<$LocalCallsTable, LocalCall> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalCallsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<int> serverId = GeneratedColumn<int>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteNumberMeta = const VerificationMeta(
    'remoteNumber',
  );
  @override
  late final GeneratedColumn<String> remoteNumber = GeneratedColumn<String>(
    'remote_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<String> direction = GeneratedColumn<String>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dispositionMeta = const VerificationMeta(
    'disposition',
  );
  @override
  late final GeneratedColumn<String> disposition = GeneratedColumn<String>(
    'disposition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _durationSecMeta = const VerificationMeta(
    'durationSec',
  );
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
    'duration_sec',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pushedMeta = const VerificationMeta('pushed');
  @override
  late final GeneratedColumn<bool> pushed = GeneratedColumn<bool>(
    'pushed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("pushed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    serverId,
    remoteNumber,
    direction,
    disposition,
    startedAt,
    durationSec,
    pushed,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_calls';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalCall> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('remote_number')) {
      context.handle(
        _remoteNumberMeta,
        remoteNumber.isAcceptableOrUnknown(
          data['remote_number']!,
          _remoteNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteNumberMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('disposition')) {
      context.handle(
        _dispositionMeta,
        disposition.isAcceptableOrUnknown(
          data['disposition']!,
          _dispositionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dispositionMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
        _durationSecMeta,
        durationSec.isAcceptableOrUnknown(
          data['duration_sec']!,
          _durationSecMeta,
        ),
      );
    }
    if (data.containsKey('pushed')) {
      context.handle(
        _pushedMeta,
        pushed.isAcceptableOrUnknown(data['pushed']!, _pushedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalCall map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalCall(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_id'],
      ),
      remoteNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_number'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}direction'],
      )!,
      disposition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}disposition'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      durationSec: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_sec'],
      )!,
      pushed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}pushed'],
      )!,
    );
  }

  @override
  $LocalCallsTable createAlias(String alias) {
    return $LocalCallsTable(attachedDatabase, alias);
  }
}

class LocalCall extends DataClass implements Insertable<LocalCall> {
  final int id;
  final int? serverId;
  final String remoteNumber;
  final String direction;
  final String disposition;
  final DateTime startedAt;
  final int durationSec;
  final bool pushed;
  const LocalCall({
    required this.id,
    this.serverId,
    required this.remoteNumber,
    required this.direction,
    required this.disposition,
    required this.startedAt,
    required this.durationSec,
    required this.pushed,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<int>(serverId);
    }
    map['remote_number'] = Variable<String>(remoteNumber);
    map['direction'] = Variable<String>(direction);
    map['disposition'] = Variable<String>(disposition);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['duration_sec'] = Variable<int>(durationSec);
    map['pushed'] = Variable<bool>(pushed);
    return map;
  }

  LocalCallsCompanion toCompanion(bool nullToAbsent) {
    return LocalCallsCompanion(
      id: Value(id),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      remoteNumber: Value(remoteNumber),
      direction: Value(direction),
      disposition: Value(disposition),
      startedAt: Value(startedAt),
      durationSec: Value(durationSec),
      pushed: Value(pushed),
    );
  }

  factory LocalCall.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalCall(
      id: serializer.fromJson<int>(json['id']),
      serverId: serializer.fromJson<int?>(json['serverId']),
      remoteNumber: serializer.fromJson<String>(json['remoteNumber']),
      direction: serializer.fromJson<String>(json['direction']),
      disposition: serializer.fromJson<String>(json['disposition']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      pushed: serializer.fromJson<bool>(json['pushed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'serverId': serializer.toJson<int?>(serverId),
      'remoteNumber': serializer.toJson<String>(remoteNumber),
      'direction': serializer.toJson<String>(direction),
      'disposition': serializer.toJson<String>(disposition),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'durationSec': serializer.toJson<int>(durationSec),
      'pushed': serializer.toJson<bool>(pushed),
    };
  }

  LocalCall copyWith({
    int? id,
    Value<int?> serverId = const Value.absent(),
    String? remoteNumber,
    String? direction,
    String? disposition,
    DateTime? startedAt,
    int? durationSec,
    bool? pushed,
  }) => LocalCall(
    id: id ?? this.id,
    serverId: serverId.present ? serverId.value : this.serverId,
    remoteNumber: remoteNumber ?? this.remoteNumber,
    direction: direction ?? this.direction,
    disposition: disposition ?? this.disposition,
    startedAt: startedAt ?? this.startedAt,
    durationSec: durationSec ?? this.durationSec,
    pushed: pushed ?? this.pushed,
  );
  LocalCall copyWithCompanion(LocalCallsCompanion data) {
    return LocalCall(
      id: data.id.present ? data.id.value : this.id,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      remoteNumber: data.remoteNumber.present
          ? data.remoteNumber.value
          : this.remoteNumber,
      direction: data.direction.present ? data.direction.value : this.direction,
      disposition: data.disposition.present
          ? data.disposition.value
          : this.disposition,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      durationSec: data.durationSec.present
          ? data.durationSec.value
          : this.durationSec,
      pushed: data.pushed.present ? data.pushed.value : this.pushed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalCall(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('remoteNumber: $remoteNumber, ')
          ..write('direction: $direction, ')
          ..write('disposition: $disposition, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSec: $durationSec, ')
          ..write('pushed: $pushed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    serverId,
    remoteNumber,
    direction,
    disposition,
    startedAt,
    durationSec,
    pushed,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalCall &&
          other.id == this.id &&
          other.serverId == this.serverId &&
          other.remoteNumber == this.remoteNumber &&
          other.direction == this.direction &&
          other.disposition == this.disposition &&
          other.startedAt == this.startedAt &&
          other.durationSec == this.durationSec &&
          other.pushed == this.pushed);
}

class LocalCallsCompanion extends UpdateCompanion<LocalCall> {
  final Value<int> id;
  final Value<int?> serverId;
  final Value<String> remoteNumber;
  final Value<String> direction;
  final Value<String> disposition;
  final Value<DateTime> startedAt;
  final Value<int> durationSec;
  final Value<bool> pushed;
  const LocalCallsCompanion({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    this.remoteNumber = const Value.absent(),
    this.direction = const Value.absent(),
    this.disposition = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.pushed = const Value.absent(),
  });
  LocalCallsCompanion.insert({
    this.id = const Value.absent(),
    this.serverId = const Value.absent(),
    required String remoteNumber,
    required String direction,
    required String disposition,
    required DateTime startedAt,
    this.durationSec = const Value.absent(),
    this.pushed = const Value.absent(),
  }) : remoteNumber = Value(remoteNumber),
       direction = Value(direction),
       disposition = Value(disposition),
       startedAt = Value(startedAt);
  static Insertable<LocalCall> custom({
    Expression<int>? id,
    Expression<int>? serverId,
    Expression<String>? remoteNumber,
    Expression<String>? direction,
    Expression<String>? disposition,
    Expression<DateTime>? startedAt,
    Expression<int>? durationSec,
    Expression<bool>? pushed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (serverId != null) 'server_id': serverId,
      if (remoteNumber != null) 'remote_number': remoteNumber,
      if (direction != null) 'direction': direction,
      if (disposition != null) 'disposition': disposition,
      if (startedAt != null) 'started_at': startedAt,
      if (durationSec != null) 'duration_sec': durationSec,
      if (pushed != null) 'pushed': pushed,
    });
  }

  LocalCallsCompanion copyWith({
    Value<int>? id,
    Value<int?>? serverId,
    Value<String>? remoteNumber,
    Value<String>? direction,
    Value<String>? disposition,
    Value<DateTime>? startedAt,
    Value<int>? durationSec,
    Value<bool>? pushed,
  }) {
    return LocalCallsCompanion(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      remoteNumber: remoteNumber ?? this.remoteNumber,
      direction: direction ?? this.direction,
      disposition: disposition ?? this.disposition,
      startedAt: startedAt ?? this.startedAt,
      durationSec: durationSec ?? this.durationSec,
      pushed: pushed ?? this.pushed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<int>(serverId.value);
    }
    if (remoteNumber.present) {
      map['remote_number'] = Variable<String>(remoteNumber.value);
    }
    if (direction.present) {
      map['direction'] = Variable<String>(direction.value);
    }
    if (disposition.present) {
      map['disposition'] = Variable<String>(disposition.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (pushed.present) {
      map['pushed'] = Variable<bool>(pushed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalCallsCompanion(')
          ..write('id: $id, ')
          ..write('serverId: $serverId, ')
          ..write('remoteNumber: $remoteNumber, ')
          ..write('direction: $direction, ')
          ..write('disposition: $disposition, ')
          ..write('startedAt: $startedAt, ')
          ..write('durationSec: $durationSec, ')
          ..write('pushed: $pushed')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $LocalCallsTable localCalls = $LocalCallsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [localCalls];
}

typedef $$LocalCallsTableCreateCompanionBuilder =
    LocalCallsCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      required String remoteNumber,
      required String direction,
      required String disposition,
      required DateTime startedAt,
      Value<int> durationSec,
      Value<bool> pushed,
    });
typedef $$LocalCallsTableUpdateCompanionBuilder =
    LocalCallsCompanion Function({
      Value<int> id,
      Value<int?> serverId,
      Value<String> remoteNumber,
      Value<String> direction,
      Value<String> disposition,
      Value<DateTime> startedAt,
      Value<int> durationSec,
      Value<bool> pushed,
    });

class $$LocalCallsTableFilterComposer
    extends Composer<_$AppDb, $LocalCallsTable> {
  $$LocalCallsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteNumber => $composableBuilder(
    column: $table.remoteNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get disposition => $composableBuilder(
    column: $table.disposition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get pushed => $composableBuilder(
    column: $table.pushed,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalCallsTableOrderingComposer
    extends Composer<_$AppDb, $LocalCallsTable> {
  $$LocalCallsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteNumber => $composableBuilder(
    column: $table.remoteNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get disposition => $composableBuilder(
    column: $table.disposition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get pushed => $composableBuilder(
    column: $table.pushed,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalCallsTableAnnotationComposer
    extends Composer<_$AppDb, $LocalCallsTable> {
  $$LocalCallsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get remoteNumber => $composableBuilder(
    column: $table.remoteNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get disposition => $composableBuilder(
    column: $table.disposition,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
    column: $table.durationSec,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get pushed =>
      $composableBuilder(column: $table.pushed, builder: (column) => column);
}

class $$LocalCallsTableTableManager
    extends
        RootTableManager<
          _$AppDb,
          $LocalCallsTable,
          LocalCall,
          $$LocalCallsTableFilterComposer,
          $$LocalCallsTableOrderingComposer,
          $$LocalCallsTableAnnotationComposer,
          $$LocalCallsTableCreateCompanionBuilder,
          $$LocalCallsTableUpdateCompanionBuilder,
          (LocalCall, BaseReferences<_$AppDb, $LocalCallsTable, LocalCall>),
          LocalCall,
          PrefetchHooks Function()
        > {
  $$LocalCallsTableTableManager(_$AppDb db, $LocalCallsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalCallsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalCallsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalCallsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                Value<String> remoteNumber = const Value.absent(),
                Value<String> direction = const Value.absent(),
                Value<String> disposition = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<int> durationSec = const Value.absent(),
                Value<bool> pushed = const Value.absent(),
              }) => LocalCallsCompanion(
                id: id,
                serverId: serverId,
                remoteNumber: remoteNumber,
                direction: direction,
                disposition: disposition,
                startedAt: startedAt,
                durationSec: durationSec,
                pushed: pushed,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> serverId = const Value.absent(),
                required String remoteNumber,
                required String direction,
                required String disposition,
                required DateTime startedAt,
                Value<int> durationSec = const Value.absent(),
                Value<bool> pushed = const Value.absent(),
              }) => LocalCallsCompanion.insert(
                id: id,
                serverId: serverId,
                remoteNumber: remoteNumber,
                direction: direction,
                disposition: disposition,
                startedAt: startedAt,
                durationSec: durationSec,
                pushed: pushed,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalCallsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDb,
      $LocalCallsTable,
      LocalCall,
      $$LocalCallsTableFilterComposer,
      $$LocalCallsTableOrderingComposer,
      $$LocalCallsTableAnnotationComposer,
      $$LocalCallsTableCreateCompanionBuilder,
      $$LocalCallsTableUpdateCompanionBuilder,
      (LocalCall, BaseReferences<_$AppDb, $LocalCallsTable, LocalCall>),
      LocalCall,
      PrefetchHooks Function()
    >;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$LocalCallsTableTableManager get localCalls =>
      $$LocalCallsTableTableManager(_db, _db.localCalls);
}
