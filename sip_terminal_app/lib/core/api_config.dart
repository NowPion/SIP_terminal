/// 服务器连接配置。
///
/// 支持两种「服务器地址」写法：
/// 1. 完整 URL（推荐生产）：`https://api.example.com/sipapi`
///    → API:  https://api.example.com/sipapi/api/v1
///    → SIP:  wss://api.example.com/ws   （经 Caddy 反代到 FS 的 5066/ws）
/// 2. 纯 IP / host:port（本机开发默认）：`10.0.2.2`
///    → API:  http://10.0.2.2:8080/api/v1
///    → SIP:  wss://10.0.2.2:7443/ws
class ApiConfig {
  ApiConfig._({
    required this.host,
    required this.httpBase,
    required this.sipWebSocketUrl,
    required this.sipDomain,
  });

  factory ApiConfig({String host = defaultHost}) {
    final raw = host.trim();
    if (raw.contains('://')) {
      final uri = Uri.parse(raw);
      final isTls = uri.scheme == 'https';
      final wsScheme = isTls ? 'wss' : 'ws';
      final portPart =
          uri.hasPort && !isTls ? ':${uri.port}' : (isTls ? '' : ':80');
      final base = '${uri.scheme}://${uri.host}$portPart${uri.path}'
          .replaceAll(RegExp(r'/+$'), '');
      return ApiConfig._(
        host: raw,
        httpBase: '$base/api/v1',
        sipWebSocketUrl: '$wsScheme://${uri.host}$portPart/ws',
        sipDomain: uri.host,
      );
    }
    final h = raw.split(':').first;
    return ApiConfig._(
      host: h,
      httpBase: 'http://$h:$httpPort/api/v1',
      sipWebSocketUrl: 'wss://$h:$sipWssPort/ws',
      sipDomain: h,
    );
  }

  static const defaultHost = '10.0.2.2';
  static const httpPort = 8080;
  static const sipWssPort = 7443;

  /// 原样保留用户输入（登录页回显）
  final String host;
  final String httpBase;
  final String sipWebSocketUrl;
  final String sipDomain; // FS challenge-realm=auto_from，digest 以挑战域为准
}
