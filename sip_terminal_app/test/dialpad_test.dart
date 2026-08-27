import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_terminal/core/theme.dart';
import 'package:sip_terminal/features/dialpad/dialpad_page.dart';
import 'package:sip_terminal/sip/call_engine.dart';
import 'package:sip_terminal/sip/sip_providers.dart';
import 'package:sip_terminal/sip/sip_service.dart';

class _FakeEngine implements CallEngine {
  @override
  Stream<SipEvent> get events => const Stream.empty();

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
  Future<void> dial(String number) async {}

  @override
  Future<void> answer() async {}

  @override
  Future<void> hangup() async {}

  @override
  Future<void> setMuted(bool muted) async {}
}

/// SipService 非密封可直接继承：记录 dial 调用作 spy。
class _RecordingSipService extends SipService {
  _RecordingSipService() : super(_FakeEngine(), onCallFinished: (_) {});

  final dialCalls = <String>[];

  @override
  Future<void> dial(String number) async => dialCalls.add(number);
}

Future<_RecordingSipService> _pumpDialpad(
  WidgetTester tester, {
  SipRegState reg = SipRegState.registered,
}) async {
  final service = _RecordingSipService();
  final container = ProviderContainer(
    overrides: [
      sipServiceProvider.overrideWithValue(service),
      sipStateProvider.overrideWith(
        (_) => Stream.value(SipServiceState(reg: reg)),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildLightTheme(), home: const DialpadPage()),
    ),
  );
  await tester.pump();
  return service;
}

void main() {
  testWidgets('按键输入 1-2-3 显示 123，退格为 12，长按清空', (tester) async {
    await _pumpDialpad(tester);
    expect(find.text('输入分机号'), findsOneWidget);

    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(find.text('123'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(find.text('12'), findsOneWidget);

    await tester.longPress(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    expect(find.text('输入分机号'), findsOneWidget);
  });

  testWidgets('空号码时呼叫按钮存在但禁用，不触发 dial', (tester) async {
    final service = await _pumpDialpad(tester);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('dial-call')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const Key('dial-call')));
    await tester.pump();
    expect(service.dialCalls, isEmpty);
  });

  testWidgets('输入 1234 后呼叫 → dial("1234") 被调用一次', (tester) async {
    final service = await _pumpDialpad(tester);

    for (final d in ['1', '2', '3', '4']) {
      await tester.tap(find.text(d));
      await tester.pump();
    }
    await tester.tap(find.byKey(const Key('dial-call')));
    await tester.pump();

    expect(service.dialCalls, ['1234']);
  });

  testWidgets('未注册时显示等待注册提示且呼叫禁用', (tester) async {
    final service = await _pumpDialpad(tester, reg: SipRegState.none);

    expect(find.text('等待注册…'), findsOneWidget);
    expect(find.text('未连接'), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('dial-call')),
    );
    expect(button.onPressed, isNull);

    await tester.tap(find.byKey(const Key('dial-call')));
    await tester.pump();
    expect(service.dialCalls, isEmpty);
  });
}
