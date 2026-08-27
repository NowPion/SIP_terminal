import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

/// 登录/注册 —— Minimal 单列，主 CTA 全宽；错误就地展示。
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _formKey = GlobalKey<FormState>();
  final _host = TextEditingController(text: '10.0.2.2');
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _tab.dispose();
    _host.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ctrl = ref.read(authControllerProvider.notifier);
      if (_tab.index == 0) {
        await ctrl.login(
            host: _host.text.trim(),
            username: _username.text.trim(),
            password: _password.text);
      } else {
        await ctrl.register(
            host: _host.text.trim(),
            username: _username.text.trim(),
            password: _password.text);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                shrinkWrap: true,
                children: [
                  Text('SIP Terminal',
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('注册账号即自动分配 SIP 分机',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: .6))),
                  const SizedBox(height: 24),
                  TabBar(
                    controller: _tab,
                    dividerColor: Colors.transparent,
                    tabs: const [Tab(text: '登录'), Tab(text: '注册')],
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _host,
                    decoration: const InputDecoration(
                        labelText: '服务器地址', hintText: '10.0.2.2'),
                    keyboardType: TextInputType.url,
                    autofillHints: const [AutofillHints.url],
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入服务器地址' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _username,
                    decoration:
                        const InputDecoration(labelText: '用户名'),
                    autofillHints: const [AutofillHints.username],
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? '用户名至少 3 位' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: '密码',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    autofillHints: const [AutofillHints.password],
                    validator: (v) =>
                        (v == null || v.length < 6) ? '密码至少 6 位' : null,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    Text(_error!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_tab.index == 0 ? '登录' : '注册并获取分机'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
