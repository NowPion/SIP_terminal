import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(initialLocation: '/dialpad', routes: [
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
  ]);
});
