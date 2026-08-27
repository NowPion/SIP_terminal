import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

class AuthResult {
  AuthResult({required this.token, required this.extension, required this.sipPassword});
  final String token;
  final String extension;
  final String sipPassword;
}

/// 认证接口抽象（便于测试注入 fake）
abstract class AuthApi {
  Future<AuthResult> register({
    required String username,
    required String password,
  });
  Future<String> login({required String username, required String password});
  Future<({String extension, String password})> me();
}

class DioAuthApi implements AuthApi {
  DioAuthApi(this._dio);
  final Dio _dio;

  @override
  Future<AuthResult> register(
      {required String username, required String password}) async {
    try {
      final r = await _dio.post('/auth/register',
          data: {'username': username, 'password': password});
      return AuthResult(
        token: r.data['token'] as String,
        extension: (r.data['sip_account'] as Map)['extension'] as String,
        sipPassword: (r.data['sip_account'] as Map)['password'] as String,
      );
    } catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<String> login(
      {required String username, required String password}) async {
    try {
      final r = await _dio
          .post('/auth/login', data: {'username': username, 'password': password});
      return r.data['token'] as String;
    } catch (e) {
      throw mapDioError(e);
    }
  }

  @override
  Future<({String extension, String password})> me() async {
    try {
      final r = await _dio.get('/me/sip-account');
      return (
        extension: r.data['extension'] as String,
        password: r.data['password'] as String
      );
    } catch (e) {
      throw mapDioError(e);
    }
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return DioAuthApi(ref.watch(apiClientProvider).dio);
});
