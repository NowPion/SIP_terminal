import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../data/app_db.dart';
import '../data/providers.dart';
import '../data/sync_repository.dart';
import '../features/auth/auth_controller.dart';
import 'call_engine.dart';
import 'sip_service.dart';
import 'ua_call_engine.dart';

final callEngineProvider = Provider<CallEngine>((_) => UaCallEngine());

final sipServiceProvider = Provider<SipService>((ref) {
  final db = ref.watch(appDbProvider);
  final sync = ref.watch(syncRepositoryProvider);
  final service = SipService(
    ref.watch(callEngineProvider),
    onCallFinished: (log) {
      // 通话终态：先落库（pushed=false 入队），再尽力上报；失败留待下次
      unawaited(_recordCall(db, sync, log));
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

Future<void> _recordCall(AppDb db, SyncRepository sync, SipCallLog log) async {
  try {
    await db
        .into(db.localCalls)
        .insert(
          LocalCallsCompanion.insert(
            remoteNumber: log.remoteNumber,
            direction: log.direction,
            disposition: log.disposition,
            startedAt: log.startedAt,
            durationSec: Value(log.durationSec),
          ),
        );
    await sync.pushPending();
  } catch (_) {
    // 落库/上报失败不向上抛（回调无法恢复）；未推送行由下次 pushPending 重试
  }
}

final sipStateProvider = StreamProvider<SipServiceState>(
  (ref) => ref.watch(sipServiceProvider).stateStream,
);

/// AuthPhase==ready 且有分机会话时启动 SIP 注册（幂等）。
Future<void> startSipIfNeeded(Ref ref) async {
  if (ref.read(authControllerProvider).valueOrNull != AuthPhase.ready) return;
  final account = await ref.read(sessionStoreProvider).sipAccount();
  if (account == null) return;
  final cfg = ref.read(apiConfigProvider);
  await ref
      .read(callEngineProvider)
      .start(account, cfg.sipWebSocketUrl, cfg.sipDomain, trustBadCert: true);
}

/// 挂到 app shell：auth 就绪即触发一次 SIP 启动。
final sipBootstrapProvider = Provider<void>((ref) {
  ref.watch(sipServiceProvider);
  var started = false;
  void kick() {
    if (started) return;
    if (ref.read(authControllerProvider).valueOrNull != AuthPhase.ready) return;
    started = true;
    startSipIfNeeded(ref);
  }

  ref.listen(authControllerProvider, (prev, next) {
    if (next.valueOrNull == AuthPhase.ready) kick();
  });
  kick();
});
