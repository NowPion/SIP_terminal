import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 前台保活服务门面：接口 + 平台实现 + 测试 no-op
/// （FakeBackgroundServiceManager）。v1 服务仅保活进程维持 SIP 连接，
/// 锁屏来电全屏唤起留 v1.1。
abstract interface class BackgroundServiceManager {
  /// 幂等启动；通知文字 '已注册 · 分机 {extension}'。
  Future<void> start({required String extension});

  /// 登出/注销时停止。
  Future<void> stop();
}

const _serviceChannelId = 'service';
const _serviceNotificationId = 9999;

/// 后台 isolate 入口：只负责更新前台通知文字。
@pragma('vm:entry-point')
Future<void> _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  service.on('update_notification').listen((event) {
    final text = event?['text'];
    if (text is String && service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'SIP Terminal',
        content: text,
      );
    }
  });
}

@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance _) async => true;

class FlutterBackgroundServiceManager implements BackgroundServiceManager {
  bool _configured = false;

  @override
  Future<void> start({required String extension}) async {
    final service = FlutterBackgroundService();
    if (!_configured) {
      await _ensureChannel();
      await service.configure(
        iosConfiguration: IosConfiguration(
          onForeground: _onServiceStart,
          onBackground: _onIosBackground,
          autoStart: false,
        ),
        androidConfiguration: AndroidConfiguration(
          onStart: _onServiceStart,
          isForegroundMode: true,
          autoStart: true,
          autoStartOnBoot: false,
          notificationChannelId: _serviceChannelId,
          initialNotificationTitle: 'SIP Terminal',
          initialNotificationContent: '已注册 · 分机 $extension',
          foregroundServiceNotificationId: _serviceNotificationId,
          foregroundServiceTypes: [AndroidForegroundType.microphone],
        ),
      );
      _configured = true;
    } else if (!await service.isRunning()) {
      await service.startService();
    }
    // 注册状态变化时更新文字；首启时若服务 isolate 尚未监听则丢弃
    // （初始文字相同，无害）。
    service.invoke('update_notification', {'text': '已注册 · 分机 $extension'});
  }

  @override
  Future<void> stop() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }

  /// configure 要求通知通道已存在；失败时插件退回默认通道。
  Future<void> _ensureChannel() async {
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _serviceChannelId,
              '服务常驻',
              description: '保持 SIP 连接',
              importance: Importance.low,
              playSound: false,
            ),
          );
    } catch (_) {
      // 同上：退回默认通道即可
    }
  }
}

final backgroundServiceProvider = Provider<BackgroundServiceManager>(
  (_) => FlutterBackgroundServiceManager(),
);

/// 测试 no-op：仅记录调用。
class FakeBackgroundServiceManager implements BackgroundServiceManager {
  int starts = 0;
  int stops = 0;
  final extensions = <String>[];

  @override
  Future<void> start({required String extension}) async {
    starts++;
    extensions.add(extension);
  }

  @override
  Future<void> stop() async => stops++;
}
