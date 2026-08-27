import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/mic_permission.dart';
import '../../core/theme.dart';
import '../../sip/sip_providers.dart';
import '../../sip/sip_service.dart';

/// 全屏通话页：UI 完全由 sipStateProvider 驱动（number 参数仅作展示兜底）。
/// 接听前统一申请麦克风运行时权限。
class CallPage extends ConsumerStatefulWidget {
  const CallPage({super.key, this.number});

  final String? number;

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  static const _autoPopAfter = Duration(seconds: 2);
  Timer? _ticker;
  Timer? _popTimer;

  SipService get _service => ref.read(sipServiceProvider);

  Future<void> _answer() async {
    if (!await ensureMicPermission(context)) return;
    if (!mounted) return;
    await _service.answer();
  }

  @override
  void initState() {
    super.initState();
    // 页面进入前通话可能已结束（极端时序）：首帧后补一次自动返回调度
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final call = ref.read(sipStateProvider).valueOrNull?.call;
      if (call?.phase == SipUiPhase.ended) _scheduleAutoPop();
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _popTimer?.cancel();
    super.dispose();
  }

  void _ensureTicker(SipUiState call) {
    final need = call.phase == SipUiPhase.active;
    if (need && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!need && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  void _scheduleAutoPop() {
    if (_popTimer != null) return;
    _popTimer = Timer(_autoPopAfter, () {
      _popTimer = null;
      if (!mounted) return;
      final router = GoRouter.maybeOf(context);
      if (router != null && router.canPop()) router.pop();
    });
  }

  String _timerText(SipUiState call) {
    final started = call.startedAt;
    if (started == null) return '00:00';
    final d = DateTime.now().difference(started);
    String two(int n) => n.clamp(0, 99).toString().padLeft(2, '0');
    return '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  String _statusText(SipUiState call, String number) => switch (call.phase) {
    SipUiPhase.idle => '',
    SipUiPhase.outgoing => '正在呼叫…',
    SipUiPhase.incoming => '来自 $number',
    SipUiPhase.active => _timerText(call),
    SipUiPhase.ended => call.message ?? '通话已结束',
  };

  @override
  Widget build(BuildContext context) {
    final sip = ref.watch(sipStateProvider);
    final call = sip.valueOrNull?.call ?? const SipUiState.idle();
    final number = (call.number?.isNotEmpty ?? false)
        ? call.number!
        : (widget.number ?? '');
    _ensureTicker(call);
    ref.listen(sipStateProvider, (_, next) {
      if (next.valueOrNull?.call.phase == SipUiPhase.ended) {
        _scheduleAutoPop();
      }
    });

    final scheme = Theme.of(context).colorScheme;
    final ringingOrActive =
        call.phase == SipUiPhase.active ||
        call.phase == SipUiPhase.incoming ||
        call.phase == SipUiPhase.outgoing;

    return PopScope(
      // 振铃/通话中拦截系统返回，防止误挂断；结束后放行（2s 自动返回）
      canPop: !ringingOrActive,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              _Avatar(number: number),
              const SizedBox(height: 24),
              Text(
                number.isEmpty ? '未知号码' : number,
                key: const Key('call-number'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusText(call, number),
                key: const Key('call-status'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceMuted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 48),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (call.phase == SipUiPhase.incoming)
                      _CircleAction(
                        key: const Key('call-answer'),
                        color: scheme.success,
                        icon: Icons.call,
                        semanticLabel: '接听',
                        onTap: _answer,
                      ),
                    if (call.phase == SipUiPhase.active) ...[
                      const _MuteButton(),
                      const SizedBox(width: 24),
                    ],
                    if (ringingOrActive)
                      _CircleAction(
                        key: const Key('call-hangup'),
                        color: scheme.error,
                        icon: Icons.call_end,
                        semanticLabel: '挂断',
                        onTap: _service.hangup,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.number});

  final String number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      height: 96,
      decoration: ShapeDecoration(
        color: scheme.surfaceContainerHighest,
        shape: const CircleBorder(),
      ),
      child: Center(
        child: number.isEmpty
            ? Icon(Icons.person, size: 40, color: scheme.onSurfaceMuted)
            : Text(
                number[0],
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurface,
                ),
              ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    super.key,
    required this.color,
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String semanticLabel;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(child: Icon(icon, size: 32, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}

class _MuteButton extends ConsumerWidget {
  const _MuteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final call = ref.watch(sipStateProvider).valueOrNull?.call;
    final muted = call?.muted ?? false;
    final label = muted ? '取消静音' : '静音';
    return Semantics(
      label: label,
      button: true,
      child: IconButton(
        key: const Key('call-mute'),
        tooltip: label,
        iconSize: 28,
        onPressed: () => ref.read(sipServiceProvider).setMuted(!muted),
        icon: Icon(muted ? Icons.mic_off : Icons.mic),
      ),
    );
  }
}
