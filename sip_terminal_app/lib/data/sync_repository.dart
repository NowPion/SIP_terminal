import 'package:drift/drift.dart';

import 'app_db.dart';

/// 上报一条通话记录所需的最小载荷
class PendingCall {
  PendingCall({
    required this.remoteNumber,
    required this.direction,
    required this.disposition,
    required this.startedAt,
    required this.durationSec,
  });

  final String remoteNumber;
  final String direction;
  final String disposition;
  final DateTime startedAt;
  final int durationSec;
}

/// 服务端返回的一条通话记录（snake_case 已在此层消化）
class ServerCall {
  ServerCall({
    required this.serverId,
    required this.remoteNumber,
    required this.direction,
    required this.disposition,
    required this.startedAt,
    required this.durationSec,
  });

  final int serverId;
  final String remoteNumber;
  final String direction;
  final String disposition;
  final DateTime startedAt;
  final int durationSec;
}

typedef CallPoster = Future<int> Function(PendingCall c);
typedef CallPageFetcher = Future<({List<ServerCall> items, Object? cursor})>
    Function({DateTime? beforeTime, int? beforeId});
typedef CallDeleter = Future<void> Function(int serverId);

class SyncRepository {
  SyncRepository(this._db,
      {required this.poster, required this.fetcher, required this.deleter});

  final AppDb _db;
  final CallPoster poster;
  final CallPageFetcher fetcher;
  final CallDeleter deleter;

  /// 尽力而为上报本地未推送记录：单条失败跳过，不影响其余。
  Future<void> pushPending() async {
    final pending = await (_db.select(_db.localCalls)
          ..where((u) => u.pushed.equals(false)))
        .get();
    for (final r in pending) {
      try {
        final serverId = await poster(PendingCall(
          remoteNumber: r.remoteNumber,
          direction: r.direction,
          disposition: r.disposition,
          startedAt: r.startedAt,
          durationSec: r.durationSec,
        ));
        await (_db.update(_db.localCalls)..where((u) => u.id.equals(r.id)))
            .write(LocalCallsCompanion(
          pushed: const Value(true),
          serverId: Value(serverId),
        ));
      } catch (_) {
        // 保留 pushed=false，下次再试
      }
    }
  }

  /// 拉取服务端记录并合并：按 serverId upsert；
  /// 本地未推送行若 (startedAt, remoteNumber, direction) 匹配则回填 serverId。
  Future<void> pullMerge() async {
    var page = await fetcher();
    var guard = 0;
    while (true) {
      await _mergePage(page.items);
      if (page.cursor == null) break;
      if (++guard > 20) break; // 分页安全阀
      // cursor 的具体形状由上层 fetcher 闭包维护，这里仅翻页
      page = await fetcher();
    }
  }

  Future<void> _mergePage(List<ServerCall> items) async {
    await _db.transaction(() async {
      for (final s in items) {
        // 1) serverId 已存在 → 更新
        final byServer = await (_db.select(_db.localCalls)
              ..where((u) => u.serverId.equals(s.serverId)))
            .getSingleOrNull();
        if (byServer != null) {
          await (_db.update(_db.localCalls)
                ..where((u) => u.id.equals(byServer.id)))
              .write(LocalCallsCompanion(
            disposition: Value(s.disposition),
            durationSec: Value(s.durationSec),
          ));
          continue;
        }
        // 2) 未推送本地行按三元组匹配 → 回填
        final matched = await (_db.select(_db.localCalls)
              ..where((u) =>
                  u.serverId.isNull() &
                  u.pushed.equals(false) &
                  u.remoteNumber.equals(s.remoteNumber) &
                  u.direction.equals(s.direction) &
                  u.startedAt.equals(s.startedAt)))
            .getSingleOrNull();
        if (matched != null) {
          await (_db.update(_db.localCalls)
                ..where((u) => u.id.equals(matched.id)))
              .write(LocalCallsCompanion(
            serverId: Value(s.serverId),
            pushed: const Value(true),
            disposition: Value(s.disposition),
            durationSec: Value(s.durationSec),
          ));
          continue;
        }
        // 3) 插入新行
        await _db.into(_db.localCalls).insert(LocalCallsCompanion.insert(
              remoteNumber: s.remoteNumber,
              direction: s.direction,
              disposition: s.disposition,
              startedAt: s.startedAt,
              durationSec: Value(s.durationSec),
              serverId: Value(s.serverId),
              pushed: const Value(true),
            ));
      }
    });
  }

  /// 本地删除；若已同步到服务端则尽力删除远端（失败不阻塞本地删除）。
  Future<void> deleteLocal(int localId) async {
    final row = await (_db.select(_db.localCalls)
          ..where((u) => u.id.equals(localId)))
        .getSingleOrNull();
    if (row == null) return;
    final sid = row.serverId;
    if (sid != null) {
      try {
        await deleter(sid);
      } catch (_) {
        // 远端删除失败不阻塞本地删除（下次拉取时会重新出现，可再删）
      }
    }
    await (_db.delete(_db.localCalls)..where((u) => u.id.equals(localId))).go();
  }

  Stream<List<LocalCall>> watchAll() {
    return (_db.select(_db.localCalls)
          ..orderBy([(u) => OrderingTerm.desc(u.startedAt)]))
        .watch();
  }
}
