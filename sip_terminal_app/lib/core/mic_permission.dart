import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

enum MicPermissionResult { granted, denied, permanentlyDenied }

/// 权限查询 seam：测试注入 granted/denied/permanentlyDenied。
typedef MicPermissionHandler = Future<MicPermissionResult> Function();

Future<MicPermissionResult> _realHandler() async {
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return MicPermissionResult.granted; // 桌面端无运行时权限概念
  }
  final status = await ph.Permission.microphone.status;
  if (status.isGranted || status.isLimited) return MicPermissionResult.granted;
  if (status.isPermanentlyDenied) return MicPermissionResult.permanentlyDenied;
  final after = await ph.Permission.microphone.request();
  if (after.isGranted || after.isLimited) return MicPermissionResult.granted;
  return after.isPermanentlyDenied
      ? MicPermissionResult.permanentlyDenied
      : MicPermissionResult.denied;
}

/// 麦克风权限依赖注入 seam。
abstract final class MicPermission {
  static MicPermissionHandler handler = _realHandler;
  static Future<void> Function() settingsOpener = ph.openAppSettings;

  /// 测试后恢复真实实现。
  static void reset() {
    handler = _realHandler;
    settingsOpener = ph.openAppSettings;
  }
}

/// 首次拨打/接听前确保 RECORD_AUDIO 已授权。
/// granted → true；denied → false（下次可再触发系统请求）；
/// permanentlyDenied → 对话框引导去系统设置（error-recovery）。
Future<bool> ensureMicPermission(BuildContext context) async {
  final result = await MicPermission.handler();
  if (result == MicPermissionResult.granted) return true;
  if (result != MicPermissionResult.permanentlyDenied) return false;
  if (!context.mounted) return false;
  final open = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('麦克风权限'),
      content: const Text('需要麦克风权限才能通话'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('去设置'),
        ),
      ],
    ),
  );
  if (open == true) {
    await MicPermission.settingsOpener();
  }
  return false;
}
