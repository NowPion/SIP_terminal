/// 服务器连接配置。默认值面向安卓模拟器（10.0.2.2 = 宿主机）。
class ApiConfig {
  ApiConfig({this.host = defaultHost});
  static const defaultHost = '10.0.2.2';
  static const httpPort = 8080;
  static const sipWssPort = 7443;

  /// 用户可改（真机填局域网 IP）
  final String host;

  String get httpBase => 'http://$host:$httpPort/api/v1';
  String get sipWebSocketUrl => 'wss://$host:$sipWssPort/ws';
  String get sipDomain => host; // FS challenge-realm=auto_from，realm 即 host
}
