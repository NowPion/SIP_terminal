import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/mic_permission.dart';
import '../../core/theme.dart';
import '../../sip/call_engine.dart';
import '../../sip/sip_providers.dart';
import '../shared/reg_badge.dart';

/// 拨号盘输入状态：挂在独立 provider，切 tab（IndexedStack 保活）不丢失。
final dialpadNumberProvider = StateProvider<String>((_) => '');

class DialpadPage extends ConsumerWidget {
  const DialpadPage({super.key});

  static const _keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '*',
    '0',
    '#',
  ];

  void _append(WidgetRef ref, String ch) {
    ref.read(dialpadNumberProvider.notifier).state += ch;
  }

  void _backspace(WidgetRef ref) {
    final n = ref.read(dialpadNumberProvider);
    if (n.isEmpty) return;
    ref.read(dialpadNumberProvider.notifier).state = n.substring(
      0,
      n.length - 1,
    );
  }

  void _clear(WidgetRef ref) {
    ref.read(dialpadNumberProvider.notifier).state = '';
  }

  Future<void> _call(BuildContext context, WidgetRef ref, String number) async {
    // 麦克风运行时权限：未授权则申请/引导，拒绝即不拨打
    if (!await ensureMicPermission(context)) return;
    if (!context.mounted) return;
    try {
      await ref.read(sipServiceProvider).dial(number);
      if (!context.mounted) return;
      // 测试环境（无 GoRouter）下不导航；正式路由 /call 始终可推。
      if (GoRouter.maybeOf(context) != null) {
        await context.push('/call?number=$number');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('呼叫失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final number = ref.watch(dialpadNumberProvider);
    final reg =
        ref.watch(sipStateProvider).valueOrNull?.reg ?? SipRegState.none;
    final registered = reg == SipRegState.registered;
    final canCall = registered && number.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('拨号'),
        // 注册状态放进 AppBar actions：省掉一整行占位，也是状态信息的惯例位置
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: RegBadge(registered: registered)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 号码贴着标题栏、留白统一落在号码与键盘之间，比把号码悬在屏幕
            // 正中更像常规拨号器；用 Expanded 承载留白，矮屏时可压缩不溢出
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      const SizedBox(width: 48),
                      Expanded(
                        child: Text(
                          number.isEmpty ? '输入分机号' : number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style:
                              (number.isEmpty
                                      ? Theme.of(
                                          context,
                                        ).textTheme.headlineSmall
                                      : Theme.of(
                                          context,
                                        ).textTheme.displaySmall)
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: number.isEmpty ? 0 : 2,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: number.isEmpty
                                        ? scheme.onSurfaceMuted
                                        : scheme.onSurface,
                                  ),
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        height: 48,
                        // 空号码时不显示退格：避免一个永久置灰的死图标
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: number.isEmpty ? 0 : 1,
                          child: IconButton(
                            tooltip: '退格（长按清空）',
                            iconSize: 24,
                            onPressed: number.isEmpty
                                ? null
                                : () => _backspace(ref),
                            onLongPress: number.isEmpty
                                ? null
                                : () => _clear(ref),
                            icon: const Icon(Icons.backspace_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _Keypad(onKey: (k) => _append(ref, k)),
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 12),
              child: Column(
                children: [
                  Semantics(
                    label: '呼叫',
                    button: true,
                    child: SizedBox(
                      width: 80,
                      height: 80,
                      child: FilledButton(
                        key: const Key('dial-call'),
                        onPressed: canCall
                            ? () => _call(context, ref, number)
                            : null,
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                          elevation: canCall ? 6 : 0,
                          shadowColor: scheme.tertiary.withValues(alpha: .45),
                          disabledBackgroundColor:
                              scheme.surfaceContainerHighest,
                          disabledForegroundColor: scheme.onSurfaceMuted
                              .withValues(alpha: .5),
                        ),
                        child: const Icon(Icons.call_rounded, size: 34),
                      ),
                    ),
                  ),
                  SizedBox(height: registered ? 0 : 10),
                  if (!registered)
                    Text(
                      '等待注册…',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  /// 数字键下方的副标签，沿用电话键盘惯例（0 键给出 + 号）。
  static const _subLabels = <String, String>{
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 20),
                _DialKey(
                  label: DialpadPage._keys[row * 3 + col],
                  subLabel: _subLabels[DialpadPage._keys[row * 3 + col]] ?? '',
                  onTap: () => onKey(DialpadPage._keys[row * 3 + col]),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _DialKey extends StatelessWidget {
  const _DialKey({
    required this.label,
    required this.subLabel,
    required this.onTap,
  });

  final String label;
  final String subLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: 76,
      height: 76,
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (subLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontSize: 9,
                      height: 1,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceMuted,
                    ),
                  ),
                ] else
                  // 槽位常在：*、# 没有字母也不会让数字相对邻键上下错位
                  const SizedBox(height: 13),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
