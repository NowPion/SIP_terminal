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

class _CallPageState extends ConsumerState<CallPage>
    with SingleTickerProviderStateMixin {
  static const _autoPopAfter = Duration(seconds: 2);
  Timer? _ticker;
  Timer? _popTimer;

  /// 振铃期间头像光环的呼吸动画
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

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
    _pulse.dispose();
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

  void _ensurePulse(SipUiState call) {
    final need =
        call.phase == SipUiPhase.incoming || call.phase == SipUiPhase.outgoing;
    if (need && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!need && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
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

  /// 号码已在上方大字展示，状态行不再重复号码。
  String _statusText(SipUiState call) => switch (call.phase) {
    SipUiPhase.idle => '',
    SipUiPhase.outgoing => '正在呼叫…',
    SipUiPhase.incoming => '来电',
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
    _ensurePulse(call);
    ref.listen(sipStateProvider, (_, next) {
      if (next.valueOrNull?.call.phase == SipUiPhase.ended) {
        _scheduleAutoPop();
      }
    });

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final live =
        call.phase == SipUiPhase.active ||
        call.phase == SipUiPhase.incoming ||
        call.phase == SipUiPhase.outgoing;

    return PopScope(
      // 振铃/通话中拦截系统返回，防止误挂断；结束后放行（2s 自动返回）
      canPop: !live,
      child: Scaffold(
        // SizedBox.expand：DecoratedBox 会收缩到 child 尺寸，不撑满则渐变只画半屏
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surfaceContainerHighest.withValues(alpha: .7),
                  scheme.surface,
                  scheme.surface,
                ],
                stops: const [0, .5, 1],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  _Avatar(number: number, pulse: _pulse),
                  const SizedBox(height: 32),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      number.isEmpty ? '未知号码' : number,
                      key: const Key('call-number'),
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _statusText(call),
                    key: const Key('call-status'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurfaceMuted,
                      fontWeight: FontWeight.w500,
                      letterSpacing: call.phase == SipUiPhase.active ? 1.2 : 0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Spacer(flex: 3),
                  _Actions(
                    phase: call.phase,
                    onAnswer: _answer,
                    onHangup: _service.hangup,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部动作区：来电=拒接/接听，通话中=静音/挂断，呼出=挂断。
class _Actions extends StatelessWidget {
  const _Actions({
    required this.phase,
    required this.onAnswer,
    required this.onHangup,
  });

  final SipUiPhase phase;
  final Future<void> Function() onAnswer;
  final Future<void> Function() onHangup;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final hangup = _CircleAction(
      key: const Key('call-hangup'),
      color: scheme.error,
      icon: Icons.call_end_rounded,
      label: phase == SipUiPhase.incoming ? '拒接' : '挂断',
      onTap: onHangup,
    );

    return switch (phase) {
      // 拒接在左、接听在右，符合安卓来电习惯
      SipUiPhase.incoming => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 56),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            hangup,
            _CircleAction(
              key: const Key('call-answer'),
              color: scheme.success,
              icon: Icons.call_rounded,
              label: '接听',
              onTap: onAnswer,
            ),
          ],
        ),
      ),
      SipUiPhase.active => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [const _MuteButton(), const SizedBox(width: 48), hangup],
      ),
      SipUiPhase.outgoing => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [hangup],
      ),
      SipUiPhase.idle || SipUiPhase.ended => const SizedBox.shrink(),
    };
  }
}

/// 圆形动作按钮 + 下方文字标签（图标语义靠标签，不再依赖 tooltip）。
class _CircleAction extends StatelessWidget {
  const _CircleAction({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: label,
          button: true,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: .32),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: color,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Center(child: Icon(icon, size: 34, color: Colors.white)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ActionLabel(label),
      ],
    );
  }
}

/// 头像：振铃时外圈光环呼吸；通话中静态。
class _Avatar extends StatelessWidget {
  const _Avatar({required this.number, required this.pulse});

  final String number;
  final Animation<double> pulse;

  static const _size = 116.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        final t = pulse.value;
        return SizedBox(
          width: _size * 1.9,
          height: _size * 1.9,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final ring in const [1.55, 1.28])
                  Container(
                    width: _size * (ring + t * .12),
                    height: _size * (ring + t * .12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.onSurface.withValues(
                        alpha: .05 * (1 - t * .5),
                      ),
                    ),
                  ),
                Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surfaceContainerHighest,
                    border: Border.all(
                      color: scheme.onSurface.withValues(alpha: .06),
                    ),
                  ),
                  child: Center(
                    child: number.isEmpty
                        ? Icon(
                            Icons.person_outline,
                            size: 48,
                            color: scheme.onSurfaceMuted,
                          )
                        : Text(
                            number.characters.first,
                            style: Theme.of(context).textTheme.displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: scheme.onSurface,
                                ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionLabel extends StatelessWidget {
  const _ActionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceMuted,
      fontWeight: FontWeight.w500,
    ),
  );
}

/// 静音：与动作按钮同尺寸，用填充/描边区分“非终止操作”与当前开关态。
class _MuteButton extends ConsumerWidget {
  const _MuteButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final muted = ref.watch(sipStateProvider).valueOrNull?.call.muted ?? false;
    final label = muted ? '取消静音' : '静音';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: label,
          button: true,
          toggled: muted,
          child: SizedBox(
            width: 76,
            height: 76,
            child: Material(
              color: muted
                  ? scheme.onSurface
                  : scheme.surfaceContainerHighest.withValues(alpha: .9),
              shape: CircleBorder(
                side: BorderSide(
                  color: scheme.onSurface.withValues(alpha: muted ? 0 : .1),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: const Key('call-mute'),
                onTap: () => ref.read(sipServiceProvider).setMuted(!muted),
                child: Center(
                  child: Icon(
                    muted ? Icons.mic_off_rounded : Icons.mic_none_rounded,
                    size: 32,
                    color: muted ? scheme.surface : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _ActionLabel(label),
      ],
    );
  }
}
