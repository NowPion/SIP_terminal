import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  GoRouter build() => GoRouter(
        initialLocation: '/dialpad',
        refreshListenable: refresh,
        redirect: (_, state) {          final phase =
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
              builder: (_, _) => const Scaffold(
                  body: Center(child: CircularProgressIndicator()))),
          GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
          GoRoute(
              path: '/dialpad',
              builder: (_, _) =>
                  const Scaffold(body: Center(child: Text('Dialpad 占位')))),
          GoRoute(
              path: '/history',
              builder: (_, _) =>
                  const Scaffold(body: Center(child: Text('History 占位')))),
          GoRoute(
              path: '/accounts',
              builder: (_, _) =>
                  const Scaffold(body: Center(child: Text('Accounts 占位')))),
        ],
      );

  final router = build();
  ref.onDispose(router.dispose);
  return router;
});
