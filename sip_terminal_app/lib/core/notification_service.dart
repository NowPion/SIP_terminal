import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// 通话通知门面：接口 + 平台实现 + 测试 no-op（FakeNotificationService）。
abstract interface class NotificationService {
  /// 创建通知通道；Android 13+ 请求 POST_NOTIFICATIONS。幂等，失败不抛。
  Future<void> init();

  /// 来电 heads-up 通知（id=8888，channel=calls，通话期间 ongoing）。
  Future<void> showCallNotification(String remoteNumber);

  /// 通话结束/取消时移除。
  Future<void> cancelCallNotification();
}

class LocalNotificationService implements NotificationService {
  static const _callChannelId = 'calls';
  static const _serviceChannelId = 'service';
  static const _callNotificationId = 8888;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  @override
  Future<void> init() async {
    if (_initialized) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_launcher'),
        ),
      );
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Android 13+ 运行时通知权限（低版本直接返回已授权）
        await Permission.notification.request();
      }
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _callChannelId,
          '通话通知',
          description: '来电与通话提醒',
          importance: Importance.high,
        ),
      );
      // 前台服务通知通道（flutter_background_service configure 前必须存在）
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _serviceChannelId,
          '服务常驻',
          description: '保持 SIP 连接',
          importance: Importance.low,
          playSound: false,
        ),
      );
      _initialized = true;
    } catch (_) {
      // 通知不可用不阻塞通话主流程；下次 init 允许重试
      _initialized = false;
    }
  }

  @override
  Future<void> showCallNotification(String remoteNumber) async {
    try {
      await _plugin.show(
        id: _callNotificationId,
        title: '来电',
        body: '来自 $remoteNumber',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _callChannelId,
            '通话通知',
            channelDescription: '来电与通话提醒',
            importance: Importance.high,
            priority: Priority.high,
            ongoing: true,
            icon: 'ic_launcher',
          ),
        ),
      );
    } catch (_) {
      // 同 init：通知失败不影响通话
    }
  }

  @override
  Future<void> cancelCallNotification() async {
    try {
      await _plugin.cancel(id: _callNotificationId);
    } catch (_) {
      // 同上
    }
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (_) => LocalNotificationService(),
);

/// 测试 no-op：仅记录调用。
class FakeNotificationService implements NotificationService {
  int inits = 0;
  int shown = 0;
  int cancelled = 0;
  final shownNumbers = <String>[];

  @override
  Future<void> init() async => inits++;

  @override
  Future<void> showCallNotification(String remoteNumber) async {
    shown++;
    shownNumbers.add(remoteNumber);
  }

  @override
  Future<void> cancelCallNotification() async => cancelled++;
}
