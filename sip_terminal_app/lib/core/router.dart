import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';
import '../features/call/call_page.dart';
import '../features/dialpad/dialpad_page.dart';
import '../features/history/history_page.dart';
import '../features/shell/home_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  GoRouter build() => GoRouter(
    initialLocation: '/dialpad',
    refreshListenable: refresh,
    redirect: (_, state) {
      final phase =
          ref.read(authControllerProvider).valueOrNull ?? AuthPhase.booting;
      final atLogin = state.matchedLocation == '/login';
      switch (phase) {
        case AuthPhase.booting:
          return atLogin ? '/login' : '/boot';
        case AuthPhase.needLogin:
          return atLogin ? null : '/login';
        case AuthPhase.ready:
          return atLogin ? '/dialpad' : null;
      }
    },
    routes: [
      GoRoute(
        path: '/boot',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/history', builder: (_, _) => const HistoryPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/dialpad', builder: (_, _) => const DialpadPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                builder: (_, _) =>
                    const Scaffold(body: Center(child: Text('Accounts 占位'))),
              ),
            ],
          ),
        ],
      ),
      // 通话页：全屏模态；状态由 sipStateProvider 驱动，number 仅展示兜底
      GoRoute(
        path: '/call',
        pageBuilder: (_, state) => MaterialPage<void>(
          fullscreenDialog: true,
          key: state.pageKey,
          child: CallPage(number: state.uri.queryParameters['number']),
        ),
      ),
    ],
  );

  final router = build();
  ref.onDispose(router.dispose);
  return router;
});
