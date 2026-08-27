import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_config.dart';

class SessionStore {
  SessionStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _s;

  static const _kToken = 'jwt';
  static const _kHost = 'host';
  static const _kExt = 'sip_ext';
  static const _kSipPass = 'sip_pass';

  Future<String?> token() => _s.read(key: _kToken);
  Future<void> setToken(String? v) => v == null
      ? _s.delete(key: _kToken)
      : _s.write(key: _kToken, value: v);

  Future<String> host() async => await _s.read(key: _kHost) ?? ApiConfig.defaultHost;
  Future<void> setHost(String v) => _s.write(key: _kHost, value: v);

  Future<({String extension, String password})?> sipAccount() async {
    final e = await _s.read(key: _kExt);
    final p = await _s.read(key: _kSipPass);
    return e == null || p == null ? null : (extension: e, password: p);
  }

  Future<void> setSipAccount(String ext, String pass) async {
    await _s.write(key: _kExt, value: ext);
    await _s.write(key: _kSipPass, value: pass);
  }

  Future<void> clear() async {
    await _s.delete(key: _kToken);
    await _s.delete(key: _kExt);
    await _s.delete(key: _kSipPass);
  }
}
