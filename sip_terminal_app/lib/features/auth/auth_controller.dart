import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/session_store.dart';
import 'auth_api.dart';

enum AuthPhase { booting, needLogin, ready }

class AuthController extends AsyncNotifier<AuthPhase> {
  SessionStore get _session => ref.read(sessionStoreProvider);
  AuthApi get _api => ref.read(authApiProvider);

  @override
  Future<AuthPhase> build() async {
    final token = await _session.token();
    if (token == null) return AuthPhase.needLogin;
    try {
      final acc = await _api.me();
      await _session.setSipAccount(acc.extension, acc.password);
      return AuthPhase.ready;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 404) {
        await _session.clear(); // 404=账号被删, 401=token 过期
        return AuthPhase.needLogin;
      }
      // 网络类错误：保持 token，允许进入主界面离线浏览
      final acc = await _session.sipAccount();
      return acc != null ? AuthPhase.ready : AuthPhase.needLogin;
    }
  }

  Future<void> _applyHost(String host) async {
    final current = await _session.host();
    if (current != host) {
      await _session.setHost(host);
      ref.invalidate(hostProvider);
      await ref.read(hostProvider.future);
    }
  }

  Future<void> login(
      {required String host,
      required String username,
      required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _applyHost(host);
      final token = await _api.login(username: username, password: password);
      await _session.setToken(token);
      final acc = await _api.me();
      await _session.setSipAccount(acc.extension, acc.password);
      return AuthPhase.ready;
    });
    if (state.hasError) await _session.setToken(null);
  }

  Future<void> register(
      {required String host,
      required String username,
      required String password}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _applyHost(host);
      final r = await _api.register(username: username, password: password);
      await _session.setToken(r.token);
      await _session.setSipAccount(r.extension, r.sipPassword);
      return AuthPhase.ready;
    });
    if (state.hasError) await _session.setToken(null);
  }

  Future<void> logout() async {
    await _session.clear();
    state = const AsyncData(AuthPhase.needLogin);
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthPhase>(AuthController.new);
