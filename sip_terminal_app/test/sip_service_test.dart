import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_terminal/core/api_client.dart';
import 'package:sip_terminal/core/background_service.dart';
import 'package:sip_terminal/core/notification_service.dart';
import 'package:sip_terminal/core/session_store.dart';
import 'package:sip_terminal/features/auth/auth_api.dart';
import 'package:sip_terminal/features/auth/auth_controller.dart';
import 'package:sip_terminal/sip/call_engine.dart';
import 'package:sip_terminal/sip/sip_providers.dart';
import 'package:sip_terminal/sip/sip_service.dart';

class FakeCallEngine implements CallEngine {
  final _ctrl = StreamController<SipEvent>.broadcast(sync: true);

  bool started = false;
  bool startTrustBadCert = false;
  String? startedWsUrl;
  String? startedDomain;
  ({String extension, String password})? startedAccount;
  final List<String> dialed = <String>[];
  bool answered = false;
  int hangups = 0;
  bool? lastMuted;

  @override
  Stream<SipEvent> get events => _ctrl.stream;

  void add(SipEvent e) => _ctrl.add(e);

  @override
  Future<void> start(
    ({String extension, String password}) account,
    String wsUrl,
    String domain, {
    bool trustBadCert = true,
  }) async {
    started = true;
    startTrustBadCert = trustBadCert;
    startedWsUrl = wsUrl;
    startedDomain = domain;
    startedAccount = account;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dial(String number) async {
    dialed.add(number);
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
  }

  @override
  Future<void> setMuted(bool muted) async {
    lastMuted = muted;
  }
}

class Clock {
  Clock(this.t);
  DateTime t;
  DateTime call() => t;
  void advance(Duration d) => t = t.add(d);
}

class FakeAuthApi implements AuthApi {
  @override
  Future<String> login({
    required String username,
    required String password,
  }) async => 'tok';

  @override
  Future<({String extension, String password})> me() async =>
      (extension: '1001', password: 'pw1');

  @override
  Future<AuthResult> register({
    required String username,
    required String password,
  }) async => AuthResult(token: 'tok', extension: '1001', sipPassword: 'pw1');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCallEngine engine;

  setUp(() => engine = FakeCallEngine());

  SipService makeService(Clock clock, List<SipCallLog> logs) {
    final s = SipService(engine, onCallFinished: logs.add, now: clock.call);
    addTearDown(s.dispose);
    return s;
  }

  CallEvent ev(SipCallDir dir, SipCallKind kind, String number) =>
      CallEvent(dir: dir, kind: kind, number: number);

  test('呼出 ring→accepted(1.2s)→ended ⇒ answered 记录与 UI 迁移', () async {
    final clock = Clock(DateTime(2026, 8, 27, 10, 0, 0));
    final logs = <SipCallLog>[];
    final service = makeService(clock, logs);
    final ui = <SipUiState>[];
    service.uiState.listen(ui.add);

    await service.dial('1002');
    expect(engine.dialed, ['1002']);
    expect(service.state.call.phase, SipUiPhase.outgoing);
    expect(service.state.call.number, '1002');

    engine.add(ev(SipCallDir.outgoing, SipCallKind.ring, '1002'));
    expect(service.state.call.phase, SipUiPhase.outgoing);

    clock.advance(const Duration(seconds: 3));
    engine.add(ev(SipCallDir.outgoing, SipCallKind.accepted, '1002'));
    expect(service.state.call.phase, SipUiPhase.active);
    expect(service.state.call.startedAt, DateTime(2026, 8, 27, 10, 0, 3));

    clock.advance(const Duration(milliseconds: 1200));
    engine.add(ev(SipCallDir.outgoing, SipCallKind.ended, '1002'));
    expect(service.state.call.phase, SipUiPhase.ended);

    expect(logs, hasLength(1));
    expect(logs.single.direction, 'out');
    expect(logs.single.remoteNumber, '1002');
    expect(logs.single.startedAt, DateTime(2026, 8, 27, 10, 0, 0));
    expect(logs.single.durationSec, 1);
    expect(logs.single.disposition, 'answered');

    await Future<void>.delayed(Duration.zero);
    expect(ui.map((s) => s.phase).toList(), [
      SipUiPhase.outgoing,
      SipUiPhase.active,
      SipUiPhase.ended,
    ]);
  });

  test('来电未接听即结束 ⇒ missed、时长 0', () async {
    final clock = Clock(DateTime(2026, 8, 27, 11, 0, 0));
    final logs = <SipCallLog>[];
    final service = makeService(clock, logs);

    engine.add(ev(SipCallDir.incoming, SipCallKind.init, '1003'));
    expect(service.state.call.phase, SipUiPhase.incoming);

    clock.advance(const Duration(seconds: 7));
    engine.add(ev(SipCallDir.incoming, SipCallKind.ended, '1003'));

    expect(logs, hasLength(1));
    expect(logs.single.direction, 'in');
    expect(logs.single.remoteNumber, '1003');
    expect(logs.single.startedAt, DateTime(2026, 8, 27, 11, 0, 0));
    expect(logs.single.durationSec, 0);
    expect(logs.single.disposition, 'missed');
    expect(service.state.call.phase, SipUiPhase.ended);
  });

  test('呼出对端忙 ⇒ busy 记录，后续 ended 不重复写', () async {
    final clock = Clock(DateTime(2026, 8, 27, 12, 0, 0));
    final logs = <SipCallLog>[];
    final service = makeService(clock, logs);

    await service.dial('1002');
    engine.add(ev(SipCallDir.outgoing, SipCallKind.busy, '1002'));
    expect(logs, hasLength(1));
    expect(logs.single.disposition, 'busy');
    expect(logs.single.durationSec, 0);
    expect(service.state.call.phase, SipUiPhase.ended);

    engine.add(ev(SipCallDir.outgoing, SipCallKind.ended, '1002'));
    expect(logs, hasLength(1));
  });

  test('呼出响铃后未接通就结束 ⇒ no_answer', () async {
    final clock = Clock(DateTime(2026, 8, 27, 13, 0, 0));
    final logs = <SipCallLog>[];
    final service = makeService(clock, logs);

    await service.dial('1002');
    engine.add(ev(SipCallDir.outgoing, SipCallKind.ring, '1002'));
    clock.advance(const Duration(seconds: 30));
    engine.add(ev(SipCallDir.outgoing, SipCallKind.ended, '1002'));

    expect(logs, hasLength(1));
    expect(logs.single.disposition, 'no_answer');
    expect(logs.single.direction, 'out');
    expect(logs.single.durationSec, 0);
  });

  test('来电接听→accepted→ended ⇒ answered；静音切换生效', () async {
    final clock = Clock(DateTime(2026, 8, 27, 14, 0, 0));
    final logs = <SipCallLog>[];
    final service = makeService(clock, logs);

    engine.add(ev(SipCallDir.incoming, SipCallKind.init, '1004'));
    await service.answer();
    expect(engine.answered, isTrue);

    clock.advance(const Duration(seconds: 2));
    engine.add(ev(SipCallDir.incoming, SipCallKind.accepted, '1004'));
    expect(service.state.call.phase, SipUiPhase.active);

    await service.setMuted(true);
    expect(engine.lastMuted, isTrue);
    expect(service.state.call.muted, isTrue);
    await service.setMuted(false);
    expect(service.state.call.muted, isFalse);

    clock.advance(const Duration(seconds: 10));
    engine.add(ev(SipCallDir.incoming, SipCallKind.ended, '1004'));

    expect(logs, hasLength(1));
    expect(logs.single.direction, 'in');
    expect(logs.single.remoteNumber, '1004');
    expect(logs.single.durationSec, 10);
    expect(logs.single.disposition, 'answered');
  });

  test('注册状态在组合状态中可见', () async {
    final clock = Clock(DateTime(2026, 8, 27, 15, 0, 0));
    final logs = <SipCallLog>[];
    final service = makeService(clock, logs);

    expect(service.regState, SipRegState.none);
    engine.add(const RegStateChanged(SipRegState.registered));
    expect(service.regState, SipRegState.registered);
    expect(service.state.reg, SipRegState.registered);
    expect(service.state.call.phase, SipUiPhase.idle);

    engine.add(const RegStateChanged(SipRegState.failed));
    expect(service.regState, SipRegState.failed);
    expect(logs, isEmpty);
  });

  test('auth 就绪 ⇒ bootstrap 以会话凭据启动引擎', () async {
    FlutterSecureStorage.setMockInitialValues({
      'jwt': 'tok',
      'sip_ext': '1001',
      'sip_pass': 'pw1',
      'host': '10.0.2.2',
    });
    final container = ProviderContainer(
      overrides: [
        callEngineProvider.overrideWithValue(engine),
        sessionStoreProvider.overrideWithValue(SessionStore()),
        authApiProvider.overrideWithValue(FakeAuthApi()),
        notificationServiceProvider.overrideWithValue(
          FakeNotificationService(),
        ),
        backgroundServiceProvider.overrideWithValue(
          FakeBackgroundServiceManager(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.future);
    expect(container.read(authControllerProvider).valueOrNull, AuthPhase.ready);

    container.read(sipBootstrapProvider);
    await Future<void>.delayed(Duration.zero);

    expect(engine.started, isTrue);
    expect(engine.startTrustBadCert, isTrue);
    expect(engine.startedAccount, (extension: '1001', password: 'pw1'));
    expect(engine.startedWsUrl, 'wss://10.0.2.2:7443/ws');
    expect(engine.startedDomain, '10.0.2.2');
  });
}
