import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_terminal/core/api_client.dart';
import 'package:sip_terminal/core/background_service.dart';
import 'package:sip_terminal/core/session_store.dart';
import 'package:sip_terminal/core/theme.dart';
import 'package:sip_terminal/features/accounts/accounts_page.dart';
import 'package:sip_terminal/features/auth/auth_api.dart';
import 'package:sip_terminal/features/auth/auth_controller.dart';
import 'package:sip_terminal/sip/call_engine.dart';
import 'package:sip_terminal/sip/sip_providers.dart';
import 'package:sip_terminal/sip/sip_service.dart';

import 'sip_service_test.dart';

class _StopCountingEngine extends FakeCallEngine {
  int stops = 0;

  @override
  Future<void> stop() async => stops++;
}

Future<
  (
    ProviderContainer,
    _StopCountingEngine,
    FakeBackgroundServiceManager,
    SessionStore,
  )
>
_pump(WidgetTester tester, {SipRegState reg = SipRegState.registered}) async {
  final engine = _StopCountingEngine();
  final bg = FakeBackgroundServiceManager();
  final store = SessionStore();
  final container = ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(FakeAuthApi()),
      sessionStoreProvider.overrideWithValue(store),
      callEngineProvider.overrideWithValue(engine),
      backgroundServiceProvider.overrideWithValue(bg),
      sipStateProvider.overrideWith(
        (_) => Stream.value(SipServiceState(reg: reg)),
      ),
    ],
  );
  addTearDown(container.dispose);
  // 真实 AuthController 走到 ready（logout 断言其效果）
  await container.read(authControllerProvider.future);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildLightTheme(), home: const AccountsPage()),
    ),
  );
  await tester.pumpAndSettle();
  return (container, engine, bg, store);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(
    () => FlutterSecureStorage.setMockInitialValues({
      'jwt': 'tok',
      'sip_ext': '1001',
      'sip_pass': 'pw1',
      'host': '192.168.1.10',
    }),
  );

  testWidgets('显示分机 1001、已注册徽标、服务器 host 与关于区', (tester) async {
    await _pump(tester);

    expect(find.byKey(const Key('accounts-page')), findsOneWidget);
    expect(find.text('1001'), findsOneWidget);
    expect(find.text('已注册'), findsOneWidget);
    expect(find.text('192.168.1.10'), findsOneWidget);
    expect(find.text('SIP 账号'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
    expect(find.text('应用版本'), findsOneWidget);
    expect(find.text('1.0.0'), findsOneWidget);
    expect(find.text('服务器协议'), findsOneWidget);
    expect(find.text('WSS+WebRTC'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
  });

  testWidgets('未注册时徽标显示未连接', (tester) async {
    await _pump(tester, reg: SipRegState.unregistered);
    expect(find.text('未连接'), findsOneWidget);
  });

  testWidgets('退出登录 → 确认对话框；取消保留会话与连接', (tester) async {
    final (_, engine, bg, store) = await _pump(tester);

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    expect(find.text('退出并断开 SIP?'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(engine.stops, 0);
    expect(bg.stops, 0);
    expect(await store.token(), 'tok');
    expect(await store.sipAccount(), isNotNull);
  });

  testWidgets('退出登录 → 确认后 engine.stop + 前台服务停止 + 会话清空', (tester) async {
    final (container, engine, bg, store) = await _pump(tester);

    await tester.tap(find.text('退出登录'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('退出'));
    await tester.pumpAndSettle();

    expect(engine.stops, 1);
    expect(bg.stops, 1);
    expect(await store.token(), isNull);
    expect(await store.sipAccount(), isNull);
    expect(
      container.read(authControllerProvider).valueOrNull,
      AuthPhase.needLogin,
    );
  });
}
