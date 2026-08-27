import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 底部导航壳：StatefulShellRoute.indexedStack 的宿主，
/// 三个分支（历史/拨号/账号）各自保活状态。
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.history_outlined, semanticLabel: '通话历史'),
            label: '历史',
            tooltip: '历史',
          ),
          NavigationDestination(
            icon: Icon(Icons.dialpad_outlined, semanticLabel: '拨号盘'),
            label: '拨号',
            tooltip: '拨号',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, semanticLabel: '账号'),
            label: '账号',
            tooltip: '账号',
          ),
        ],
      ),
    );
  }
}
