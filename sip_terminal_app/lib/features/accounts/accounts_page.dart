import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/api_config.dart';
import '../../core/background_service.dart';
import '../../core/theme.dart';
import '../../sip/call_engine.dart';
import '../../sip/sip_providers.dart';
import '../auth/auth_controller.dart';
import '../shared/reg_badge.dart';

/// 分机会话（extension/password）；登出后路由守卫会离开本页。
final _sipAccountProvider =
    FutureProvider<({String extension, String password})?>(
      (ref) => ref.watch(sessionStoreProvider).sipAccount(),
    );

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});

  static const _appVersion = '1.0.0';
  static const _serverProtocol = 'WSS+WebRTC';

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出并断开 SIP?'),
        content: const Text('将断开 SIP 注册并清除本机登录会话。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('退出', style: TextStyle(color: scheme.error)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // 先断 SIP 与前台服务，再清会话（路由守卫自动回登录页）
    await ref.read(callEngineProvider).stop();
    await ref.read(backgroundServiceProvider).stop();
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final account = ref.watch(_sipAccountProvider).valueOrNull;
    final reg =
        ref.watch(sipStateProvider).valueOrNull?.reg ?? SipRegState.none;
    final host = ref.watch(hostProvider).valueOrNull ?? ApiConfig.defaultHost;

    return Scaffold(
      key: const Key('accounts-page'),
      appBar: AppBar(title: const Text('账号')),
      body: ListView(
        children: [
          const _SectionHeader(text: 'SIP 账号'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account?.extension ?? '—',
                    key: const Key('accounts-ext'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 8),
                  RegBadge(registered: reg == SipRegState.registered),
                  const SizedBox(height: 12),
                  Text(
                    host,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.logout, color: scheme.error),
            title: Text(
              '退出登录',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: scheme.error),
            ),
            onTap: () => _confirmLogout(context, ref),
          ),
          const Divider(indent: 16, endIndent: 16),
          const _SectionHeader(text: '关于'),
          const _AboutRow(label: '应用版本', value: _appVersion),
          const _AboutRow(label: '服务器协议', value: _serverProtocol),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: scheme.onSurfaceMuted),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceMuted),
      ),
    );
  }
}
