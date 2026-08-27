import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_terminal/core/api_client.dart';
import 'package:sip_terminal/core/session_store.dart';
import 'package:sip_terminal/features/auth/auth_api.dart';
import 'package:sip_terminal/features/auth/login_page.dart';

import 'auth_controller_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ProviderContainer> pump(WidgetTester tester, FakeAuthApi api) async {
    final c = ProviderContainer(overrides: [
      authApiProvider.overrideWithValue(api),
      sessionStoreProvider.overrideWithValue(SessionStore()),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pump();
    return c;
  }

  testWidgets('空表单提交 → 显示校验错误且不调用 API', (tester) async {
    final api = FakeAuthApi();
    await pump(tester, api);

    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump();

    expect(find.text('用户名至少 3 位'), findsOneWidget);
    expect(find.text('密码至少 6 位'), findsOneWidget);
    expect(api.loginCalls, 0);
    expect(api.registerCalls, 0);
  });

  testWidgets('密码可见性切换', (tester) async {
    await pump(tester, FakeAuthApi());

    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
  });
}
