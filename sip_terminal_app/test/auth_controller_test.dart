import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_terminal/core/api_client.dart';
import 'package:sip_terminal/core/session_store.dart';
import 'package:sip_terminal/features/auth/auth_api.dart';
import 'package:sip_terminal/features/auth/auth_controller.dart';

class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.meThrows});
  int loginCalls = 0;
  int registerCalls = 0;
  Object? meThrows;

  @override
  Future<AuthResult> register(
      {required String username, required String password}) async {
    registerCalls++;
    return AuthResult(token: 'reg-tok', extension: '1001', sipPassword: 'pw1');
  }

  @override
  Future<String> login(
      {required String username, required String password}) async {
    loginCalls++;
    return 'login-tok';
  }

  @override
  Future<({String extension, String password})> me() async {
    final t = meThrows;
    if (t != null) throw t;
    return (extension: '1001', password: 'pw1');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Future<ProviderContainer> makeContainer(FakeAuthApi api) async {
    final c = ProviderContainer(overrides: [
      authApiProvider.overrideWithValue(api),
      sessionStoreProvider.overrideWithValue(SessionStore()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('未登录启动 → needLogin', () async {
    final c = await makeContainer(FakeAuthApi());
    final phase = await c.read(authControllerProvider.future);
    expect(phase, AuthPhase.needLogin);
  });

  test('有 token 且 me 正常 → ready（静默恢复）', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt': 'old-tok'});
    final c = await makeContainer(FakeAuthApi());
    final phase = await c.read(authControllerProvider.future);
    expect(phase, AuthPhase.ready);
  });

  test('token 过期(401) → 清除并 needLogin', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt': 'expired'});
    final c =
        await makeContainer(FakeAuthApi(meThrows: ApiException('unauthorized', statusCode: 401)));
    final phase = await c.read(authControllerProvider.future);
    expect(phase, AuthPhase.needLogin);
    expect(await c.read(sessionStoreProvider).token(), isNull);
  });

  test('登录成功 → ready 且会话写入', () async {
    final api = FakeAuthApi();
    final c = await makeContainer(api);
    await c.read(authControllerProvider.future);

    await c.read(authControllerProvider.notifier).login(
        host: '192.168.0.5', username: 'alice', password: 'secret6');

    final phase = c.read(authControllerProvider).valueOrNull;
    expect(phase, AuthPhase.ready);
    expect(api.loginCalls, 1);
    final s = c.read(sessionStoreProvider);
    expect(await s.token(), 'login-tok');
    expect(await s.host(), '192.168.0.5');
    expect(await s.sipAccount(),
        (extension: '1001', password: 'pw1'));
  });

  test('登录失败(网络) → needLogin 且 token 不残留', () async {
    final api = FakeAuthApi(meThrows: ApiException('网络错误'));
    final c = await makeContainer(api);
    await c.read(authControllerProvider.future);

    await c.read(authControllerProvider.notifier).login(
        host: '10.0.2.2', username: 'alice', password: 'secret6');

    expect(c.read(authControllerProvider).hasError, isTrue);
    expect(await c.read(sessionStoreProvider).token(), isNull);
    final phase = c.read(authControllerProvider).valueOrNull ?? AuthPhase.needLogin;
    expect(phase, isNot(AuthPhase.ready));
  });

  test('注册成功 → ready 且拿到分机', () async {
    final api = FakeAuthApi();
    final c = await makeContainer(api);
    await c.read(authControllerProvider.future);

    await c.read(authControllerProvider.notifier).register(
        host: '10.0.2.2', username: 'bob02', password: 'secret6');

    expect(c.read(authControllerProvider).valueOrNull, AuthPhase.ready);
    expect(api.registerCalls, 1);
  });

  test('logout → needLogin 且会话清空', () async {
    FlutterSecureStorage.setMockInitialValues({'jwt': 't', 'sip_ext': '1001'});
    final c = await makeContainer(FakeAuthApi());
    await c.read(authControllerProvider.notifier).logout();
    expect(c.read(authControllerProvider).valueOrNull, AuthPhase.needLogin);
    expect(await c.read(sessionStoreProvider).token(), isNull);
  });
}
