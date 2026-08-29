import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'session_store.dart';

/// 持久化的服务器 host；登录页修改后 invalidate 即全链路生效。
final hostProvider = FutureProvider<String>((ref) {
  return ref.watch(sessionStoreProvider).host();
});

final apiConfigProvider = Provider<ApiConfig>((ref) {
  final host = ref.watch(hostProvider).valueOrNull ?? ApiConfig.defaultHost;
  return ApiConfig(host: host);
});

class ApiClient {
  ApiClient(this._cfg, this._session)
      : dio = Dio(BaseOptions(
          baseUrl: _cfg.httpBase,
          connectTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 12),
        )) {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
    ));
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
      final t = await _session.token();
      if (t != null) o.headers['Authorization'] = 'Bearer $t';
      h.next(o);
    }));
  }

  final Dio dio;
  final ApiConfig _cfg;
  final SessionStore _session;

  ApiConfig get config => _cfg;
}

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());
final apiClientProvider = Provider<ApiClient>(
    (ref) => ApiClient(ref.watch(apiConfigProvider), ref.watch(sessionStoreProvider)));

/// 业务错误：msg 为服务端 error 字段或网络描述
class ApiException implements Exception {
  ApiException(this.msg, {this.statusCode});
  final String msg;
  final int? statusCode;
  @override
  String toString() => msg;
}

Exception mapDioError(Object e) {
  if (e is DioException) {
    final r = e.response;
    if (r?.data is Map && (r!.data as Map)['error'] is String) {
      return ApiException((r.data as Map)['error'] as String,
          statusCode: r.statusCode);
    }
    return ApiException('网络错误：${e.message ?? e.type.name}',
        statusCode: r?.statusCode);
  }
  return ApiException('未知错误：$e');
}
