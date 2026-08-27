import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../sip/call_engine.dart';
import '../../sip/sip_providers.dart';

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
    await ref.read(sipServiceProvider).dial(number);
    if (!context.mounted) return;
    // 测试环境（无 GoRouter）下不导航；正式路由 /call 始终可推。
    if (GoRouter.maybeOf(context) != null) {
      await context.push('/call?number=$number');
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
      appBar: AppBar(title: const Text('拨号')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Align(
                alignment: Alignment.centerRight,
                child: _RegBadge(registered: registered),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        number.isEmpty ? '输入分机号' : number,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
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
                      child: IconButton(
                        tooltip: '退格',
                        iconSize: 24,
                        onPressed: number.isEmpty
                            ? null
                            : () => _backspace(ref),
                        onLongPress: number.isEmpty ? null : () => _clear(ref),
                        icon: const Icon(Icons.backspace_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _Keypad(onKey: (k) => _append(ref, k)),
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 12),
              child: Column(
                children: [
                  Semantics(
                    label: '呼叫',
                    button: true,
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: FilledButton(
                        key: const Key('dial-call'),
                        onPressed: canCall
                            ? () => _call(context, ref, number)
                            : null,
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                        ),
                        child: const Icon(Icons.call, size: 32),
                      ),
                    ),
                  ),
                  if (!registered)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '等待注册…',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceMuted,
                        ),
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

class _RegBadge extends StatelessWidget {
  const _RegBadge({required this.registered});

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

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onKey});

  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var col = 0; col < 3; col++) ...[
                if (col > 0) const SizedBox(width: 8),
                _DialKey(
                  label: DialpadPage._keys[row * 3 + col],
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
  const _DialKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
