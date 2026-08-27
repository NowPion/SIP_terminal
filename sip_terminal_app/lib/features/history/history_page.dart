import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/app_db.dart';
import '../../data/providers.dart';
import 'history_controller.dart';

/// 优先在底部导航壳内切回拨号分支；脱离壳（如测试）时走路由。
void _goDialpad(BuildContext context) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.goBranch(0);
    return;
  }
  if (GoRouter.maybeOf(context) != null) context.go('/dialpad');
}

/// 通话历史页：本地 DB 流驱动；下拉刷新上报+合并；滑动删除（确认后本地删除）。
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(historyControllerProvider).refresh();
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('刷新失败'),
            action: SnackBarAction(
              label: '重试',
              onPressed: () => _refresh(context, ref),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calls = ref.watch(historyListProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('通话历史')),
      body: SafeArea(
        child: calls.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '加载失败',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => ref.invalidate(historyListProvider),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
          data: (list) => RefreshIndicator(
            onRefresh: () => _refresh(context, ref),
            child: list.isEmpty
                ? const _EmptyState()
                : ListView.builder(
                    key: const Key('history-list'),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: list.length,
                    itemBuilder: (_, i) => _CallRow(
                      call: list[i],
                      onDelete: () async {
                        await ref
                            .read(syncRepositoryProvider)
                            .deleteLocal(list[i].id);
                      },
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// 空状态：引导去拨号。
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          key: const Key('history-empty'),
          height: constraints.maxHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 64,
                color: scheme.onSurfaceMuted,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无通话',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                '去拨号开始第一通电话',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceMuted),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => _goDialpad(context),
                child: const Text('去拨号'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单行通话记录：方向图标 + 号码 + 相对时间（+时长），未同步小圆点。
class _CallRow extends StatelessWidget {
  const _CallRow({required this.call, required this.onDelete});

  final LocalCall call;
  final Future<void> Function() onDelete;

  IconData get _directionIcon => switch (call.direction) {
    'in' => Icons.call_received,
    'missed' => Icons.call_missed_outgoing,
    _ => Icons.call_made,
  };

  String _timeLabel(DateTime now) {
    final t = call.startedAt.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final hm = '$hh:$mm';
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    if (day == today) return '今天 $hm';
    if (day == today.subtract(const Duration(days: 1))) return '昨天 $hm';
    return '${t.month}月${t.day}日 $hm';
  }

  String get _durationLabel {
    final m = call.durationSec ~/ 60;
    final s = call.durationSec % 60;
    return m == 0 ? '$s秒' : '$m分$s秒';
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条通话记录?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final missed = call.direction == 'missed';

    return Dismissible(
      key: ValueKey('call-${call.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        color: scheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              _directionIcon,
              size: 22,
              color: missed ? scheme.error : scheme.onSurfaceMuted,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    call.remoteNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _timeLabel(DateTime.now()),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceMuted,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (call.durationSec > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          _durationLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceMuted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (!call.pushed)
              Semantics(
                label: '未同步',
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.circle, size: 6, color: scheme.tertiary),
                ),
              ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
