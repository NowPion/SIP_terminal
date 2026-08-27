import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sip_terminal/core/mic_permission.dart';
import 'package:sip_terminal/core/theme.dart';
import 'package:sip_terminal/data/app_db.dart';
import 'package:sip_terminal/data/providers.dart';
import 'package:sip_terminal/data/sync_repository.dart';
import 'package:sip_terminal/features/call/call_page.dart';
import 'package:sip_terminal/sip/call_engine.dart';
import 'package:sip_terminal/sip/sip_providers.dart';

class FakeCallEngine implements CallEngine {
  final _ctrl = StreamController<SipEvent>.broadcast(sync: true);

  final List<String> dialed = <String>[];
  bool answered = false;
  int hangups = 0;
  bool? lastMuted;
  String? _number;
  SipCallDir _dir = SipCallDir.outgoing;
  bool _finished = true;

  @override
  Stream<SipEvent> get events => _ctrl.stream;

  void add(SipEvent e) => _ctrl.add(e);

  @override
  Future<void> start(
    ({String extension, String password}) account,
    String wsUrl,
    String domain, {
    bool trustBadCert = true,
  }) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dial(String number) async {
    dialed.add(number);
    _number = number;
    _dir = SipCallDir.outgoing;
    _finished = false;
    add(
      CallEvent(
        dir: SipCallDir.outgoing,
        kind: SipCallKind.init,
        number: number,
      ),
    );
  }

  @override
  Future<void> answer() async {
    answered = true;
  }

  @override
  Future<void> hangup() async {
    hangups++;
    // 模拟真实引擎：我方挂断 → 对端回 BYE → ended 事件
    if (!_finished) {
      _finished = true;
      add(CallEvent(dir: _dir, kind: SipCallKind.ended, number: _number));
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    lastMuted = muted;
  }
}

Future<ProviderContainer> _pumpCall(
  WidgetTester tester,
  AppDb db,
  FakeCallEngine engine, {
  GoRouter? router,
  String number = '1002',
}) async {
  final repo = SyncRepository(
    db,
    poster: (_) async => 1,
    fetcher: ({beforeTime, beforeId}) async =>
        (items: const <ServerCall>[], cursor: null),
    deleter: (_) async {},
  );
  final container = ProviderContainer(
    overrides: [
      appDbProvider.overrideWithValue(db),
      syncRepositoryProvider.overrideWithValue(repo),
      callEngineProvider.overrideWithValue(engine),
    ],
  );
  addTearDown(container.dispose);

  final app = router != null
      ? MaterialApp.router(theme: buildLightTheme(), routerConfig: router)
      : MaterialApp(
          theme: buildLightTheme(),
          home: CallPage(number: number),
        );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: app),
  );
  await tester.pump();
  return container;
}

GoRouter _probeRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: Text('拨号盘')),
    ),
    GoRoute(
      path: '/call',
      builder: (_, state) =>
          CallPage(number: state.uri.queryParameters['number']),
    ),
  ],
);

/// SipService 状态流是异步 broadcast controller：同步发出的引擎事件
/// 要等微task投递，pump 一帧看不到，统一再补一帧。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

void main() {
  late AppDb db;
  late FakeCallEngine engine;

  setUp(() {
    db = AppDb.forTest(NativeDatabase.memory());
    engine = FakeCallEngine();
    // 接听走真实 handler 会命中缺失的插件；测试固定为已授权
    MicPermission.handler = () async => MicPermissionResult.granted;
  });
  tearDown(() => db.close());

  testWidgets('呼出接通 → 计时出现，挂断 → 引擎挂断且记录落库 answered', (tester) async {
    final container = await _pumpCall(tester, db, engine);
    await tester.pump();

    await container.read(sipServiceProvider).dial('1002');
    await tester.pump();
    expect(find.text('正在呼叫…'), findsOneWidget);
    expect(find.byKey(const Key('call-hangup')), findsOneWidget);
    expect(find.byKey(const Key('call-answer')), findsNothing);
    expect(find.byKey(const Key('call-mute')), findsNothing);

    engine.add(
      const CallEvent(
        dir: SipCallDir.outgoing,
        kind: SipCallKind.accepted,
        number: '1002',
      ),
    );
    await _settle(tester);
    expect(find.byKey(const Key('call-mute')), findsOneWidget);
    final status = tester
        .widget<Text>(find.byKey(const Key('call-status')))
        .data!;
    expect(RegExp(r'^00:0\d$').hasMatch(status), isTrue);

    await tester.tap(find.byKey(const Key('call-mute')));
    await _settle(tester);
    expect(engine.lastMuted, isTrue);
    expect(find.byTooltip('取消静音'), findsOneWidget);

    await tester.tap(find.byKey(const Key('call-hangup')));
    await _settle(tester);
    expect(engine.hangups, 1);
    expect(find.text('通话已结束'), findsOneWidget);

    // 记录已落库（后续 pushPending 把它置为已上报）
    final rows = await db.select(db.localCalls).get();
    expect(rows, hasLength(1));
    expect(rows.single.direction, 'out');
    expect(rows.single.remoteNumber, '1002');
    expect(rows.single.disposition, 'answered');
  });

  testWidgets('来电 → 显示接听/挂断，接听 → engine.answer 被调用', (tester) async {
    await _pumpCall(tester, db, engine);

    engine.add(
      const CallEvent(
        dir: SipCallDir.incoming,
        kind: SipCallKind.init,
        number: '1003',
      ),
    );
    await _settle(tester);
    expect(find.text('来自 1003'), findsOneWidget);
    expect(find.byKey(const Key('call-answer')), findsOneWidget);
    expect(find.byKey(const Key('call-hangup')), findsOneWidget);

    await tester.tap(find.byKey(const Key('call-answer')));
    await _settle(tester);
    expect(engine.answered, isTrue);
  });

  testWidgets('ended 原因映射：对端忙 → 对方忙', (tester) async {
    final container = await _pumpCall(tester, db, engine);
    await container.read(sipServiceProvider).dial('1002');
    await tester.pump();

    engine.add(
      const CallEvent(
        dir: SipCallDir.outgoing,
        kind: SipCallKind.busy,
        number: '1002',
      ),
    );
    await _settle(tester);
    expect(find.text('对方忙'), findsOneWidget);
    final rows = await db.select(db.localCalls).get();
    expect(rows.single.disposition, 'busy');
    expect(rows.single.durationSec, 0);
  });

  testWidgets('ended 2s 后自动返回上一路由', (tester) async {
    final router = _probeRouter();
    final container = await _pumpCall(tester, db, engine, router: router);
    await tester.pump();
    expect(find.text('拨号盘'), findsOneWidget);

    router.push('/call?number=1002');
    await tester.pump();
    await container.read(sipServiceProvider).dial('1002');
    await tester.pump();
    engine.add(
      const CallEvent(
        dir: SipCallDir.outgoing,
        kind: SipCallKind.accepted,
        number: '1002',
      ),
    );
    await _settle(tester);

    // 通话中系统返回被拦截：只有挂断能结束
    await tester.tap(find.byKey(const Key('call-hangup')));
    await _settle(tester);
    expect(find.text('通话已结束'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('拨号盘'), findsOneWidget);
    expect(find.byKey(const Key('call-hangup')), findsNothing);
  });

  testWidgets('振铃中系统返回被 PopScope 拦截，不离开通话页', (tester) async {
    final router = _probeRouter();
    final container = await _pumpCall(tester, db, engine, router: router);
    router.push('/call?number=1002');
    await tester.pump();

    await container.read(sipServiceProvider).dial('1002');
    await tester.pump();
    expect(find.text('正在呼叫…'), findsOneWidget);

    // 模拟系统返回（PredictiveBack 以 pop 的形式到达，被 canPop=false 拦截）
    final navigator = router.routerDelegate.navigatorKey.currentContext;
    expect(navigator, isNotNull);
    await Navigator.maybePop(navigator!);
    await _settle(tester);
    // 仍在通话页，未被返回键带走
    expect(find.text('正在呼叫…'), findsOneWidget);
    expect(find.byKey(const Key('call-hangup')), findsOneWidget);
  });
}
