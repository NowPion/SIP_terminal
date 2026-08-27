import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// 注册状态徽标（拨号盘/账号页共用）：圆点 + 已注册/未连接。
class RegBadge extends StatelessWidget {
  const RegBadge({super.key, required this.registered});

  final bool registered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = registered ? '已注册' : '未连接';
    return Semantics(
      label: 'SIP 注册状态：$label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: ShapeDecoration(
          color: scheme.surfaceContainerHighest,
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: scheme.success),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: scheme.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}
