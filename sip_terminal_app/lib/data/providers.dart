import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import 'app_db.dart';
import 'sync_repository.dart';

ServerCall _serverCallFromMap(Map<dynamic, dynamic> m) => ServerCall(
  serverId: (m['id'] as num).toInt(),
  remoteNumber: m['remote_number'] as String? ?? '',
  direction: m['direction'] as String? ?? '',
  disposition: m['disposition'] as String? ?? '',
  startedAt: DateTime.parse(m['started_at'] as String).toUtc(),
  durationSec: (m['duration_sec'] as num?)?.toInt() ?? 0,
);

/// 生产装配：SyncRepository 直连 dio（token 由 ApiClient 拦截器注入）。
final syncRepositoryProvider = Provider<SyncRepository>((ref) {
  final db = ref.watch(appDbProvider);
  final dio = ref.watch(apiClientProvider).dio;
  // next_cursor 原样透传（{time: int64ms, id: int64}），
  // 翻页时才落成 before_time(RFC3339Nano)/before_id 查询参数。
  Object? nextCursor;
  return SyncRepository(
    db,
    poster: (c) async {
      final res = await dio.post<Map<dynamic, dynamic>>(
        '/calls',
        data: {
          'direction': c.direction,
          'disposition': c.disposition,
          'remote_number': c.remoteNumber,
          'started_at': c.startedAt.toUtc().toIso8601String(),
          'duration_sec': c.durationSec,
        },
      );
      return (res.data?['id'] as num).toInt();
    },
    fetcher: ({beforeTime, beforeId}) async {
      // 显式 before* 参数优先；否则以上一页 next_cursor 续页
      DateTime? time = beforeTime;
      int? id = beforeId;
      final cursor = nextCursor;
      if (time == null && id == null && cursor is Map) {
        final ms = cursor['time'];
        final cid = cursor['id'];
        if (ms is int) {
          time = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        }
        if (cid is int) id = cid;
      }
      final res = await dio.get<Map<dynamic, dynamic>>(
        '/calls',
        queryParameters: {
          'limit': 100,
          'before_time': ?time?.toUtc().toIso8601String(),
          'before_id': ?id,
        },
      );
      nextCursor = res.data?['next_cursor'];
      final items = ((res.data?['items'] as List?) ?? const [])
          .whereType<Map>()
          .map(_serverCallFromMap)
          .toList();
      return (items: items, cursor: nextCursor);
    },
    deleter: (serverId) => dio.delete<void>('/calls/$serverId'),
  );
});
