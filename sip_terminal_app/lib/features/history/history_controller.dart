import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_db.dart';
import '../../data/providers.dart';
import '../../data/sync_repository.dart';

/// 历史列表流：DB 变更（上报回填/服务端合并/本地删除）自动驱动 UI 刷新。
final historyListProvider = StreamProvider<List<LocalCall>>((ref) {
  return ref.watch(syncRepositoryProvider).watchAll();
});

/// 同步动作：下拉刷新 = 尽力上报未推送记录 → 拉取服务端记录合并。
class HistoryController {
  HistoryController(this._repo);

  final SyncRepository _repo;

  Future<void> refresh() async {
    await _repo.pushPending();
    await _repo.pullMerge();
  }
}

final historyControllerProvider = Provider<HistoryController>((ref) {
  return HistoryController(ref.watch(syncRepositoryProvider));
});
