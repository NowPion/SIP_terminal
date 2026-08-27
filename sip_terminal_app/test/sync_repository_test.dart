import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_terminal/data/app_db.dart';
import 'package:sip_terminal/data/sync_repository.dart';

void main() {
  late AppDb db;
  setUp(() => db = AppDb.forTest(NativeDatabase.memory()));
  tearDown(() => db.close());

  LocalCallsCompanion row({
    String number = '1002',
    String direction = 'out',
    String disposition = 'answered',
    DateTime? startedAt,
    bool pushed = false,
  }) =>
      LocalCallsCompanion.insert(
        remoteNumber: number,
        direction: direction,
        disposition: disposition,
        startedAt:
            startedAt ?? DateTime.fromMillisecondsSinceEpoch(1700000000000),
        pushed: Value(pushed),
      );

  SyncRepository makeRepo({
    required CallPoster poster,
    List<ServerCall> items = const [],
  }) =>
      SyncRepository(db,
          poster: poster,
          fetcher: ({beforeTime, beforeId}) async =>
              (items: items, cursor: null),
          deleter: (_) async {});

  test('pushPending 上报未推送记录并回填 serverId', () async {
    await db.into(db.localCalls).insert(row(number: '1002'));
    await db.into(db.localCalls).insert(row(number: '1003'));

    final posted = <String>[];
    final repo = makeRepo(poster: (c) async {
      posted.add('${c.remoteNumber}:${c.direction}');
      return posted.length;
    });

    await repo.pushPending();

    expect(posted, ['1002:out', '1003:out']);
    final all = await db.select(db.localCalls).get();
    for (final r in all) {
      expect(r.pushed, isTrue);
      expect(r.serverId, isNotNull);
    }
  });

  test('pushPending 失败的记录跳过且不中断其余', () async {
    await db.into(db.localCalls).insert(row(number: 'bad'));
    await db.into(db.localCalls).insert(row(number: 'good'));

    final repo = makeRepo(
        poster: (c) async => c.remoteNumber == 'bad' ? throw Exception('net') : 99);

    await repo.pushPending(); // 不应抛出

    final rows = await db.select(db.localCalls).get();
    final byNum = {for (final r in rows) r.remoteNumber: r};
    expect(byNum['bad']!.pushed, isFalse);
    expect(byNum['good']!.pushed, isTrue);
    expect(byNum['good']!.serverId, 99);
  });

  test('pullMerge 按 serverId upsert 并回填匹配的本地未推送行', () async {
    final t = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    await db.into(db.localCalls).insert(row(number: '1002', startedAt: t));

    final repo = makeRepo(
        poster: (_) async => 1,
        items: [
          ServerCall(
            serverId: 7,
            remoteNumber: '1002',
            direction: 'out',
            disposition: 'answered',
            startedAt: t.toUtc(),
            durationSec: 63,
          ),
          ServerCall(
            serverId: 8,
            remoteNumber: '1009',
            direction: 'in',
            disposition: 'missed',
            startedAt: t.toUtc().subtract(const Duration(minutes: 5)),
            durationSec: 0,
          ),
        ]);

    await repo.pullMerge();

    final rows = await (db.select(db.localCalls)
          ..orderBy([(u) => OrderingTerm.desc(u.startedAt)]))
        .get();
    expect(rows.length, 2);
    // 原本地行被回填而非重复插入（1002@t 较新，desc 排第一）
    expect(rows.first.serverId, 7);
    expect(rows.first.remoteNumber, '1002');
    expect(rows.first.durationSec, 63);
    expect(rows.last.serverId, 8);
  });

  test('watchAll 按开始时间倒序', () async {
    final old = DateTime.fromMillisecondsSinceEpoch(1690000000000);
    final new_ = DateTime.fromMillisecondsSinceEpoch(1700000000000);
    await db.into(db.localCalls).insert(row(number: '1', startedAt: old));
    await db.into(db.localCalls).insert(row(number: '2', startedAt: new_));

    final repo = makeRepo(poster: (_) async => 1);

    final list = await repo.watchAll().first;
    expect(list.first.remoteNumber, '2');
  });

  test('deleteLocal 删除本地行', () async {
    final id = await db.into(db.localCalls).insert(row(number: '1002'));
    final repo = makeRepo(poster: (_) async => 1);

    await repo.deleteLocal(id);

    final rows = await db.select(db.localCalls).get();
    expect(rows, isEmpty);
  });
}
