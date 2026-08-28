import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/mic_permission.dart';
import '../../core/theme.dart';
import '../../data/app_db.dart';
import '../../data/providers.dart';
import '../../sip/sip_providers.dart';
import '../dialpad/dialpad_page.dart';
import 'history_controller.dart';

enum HistoryFilter { all, missed, out, incoming }

final historyFilterProvider = StateProvider<HistoryFilter>((_) => HistoryFilter.all);

/// 优先在底部导航壳内切回拨号分支；脱离壳（如测试）时走路由。
void _goDialpad(BuildContext context) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell != null) {
    shell.goBranch(1); // 拨号盘在 branch 1
    return;
  }
  if (GoRouter.maybeOf(context) != null) context.go('/dialpad');
}

/// 快速回拨
Future<void> _quickCallBack(BuildContext context, WidgetRef ref, String number) async {
  if (!await ensureMicPermission(context)) return;
  if (!context.mounted) return;
  ref.read(dialpadNumberProvider.notifier).state = number;
  try {
    await ref.read(sipServiceProvider).dial(number);
    if (!context.mounted) return;
    if (GoRouter.maybeOf(context) != null) {
      await context.push('/call?number=$number');
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('呼叫失败: $e')),
      );
    }
  }
}

/// 通话历史页：现代化卡片流、类型过滤 Chip、快速回拨与平滑滑动删除
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
    final callsAsync = ref.watch(historyListProvider);
    final filter = ref.watch(historyFilterProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('通话历史'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: '全部',
                    selected: filter == HistoryFilter.all,
                    onSelected: () => ref.read(historyFilterProvider.notifier).state = HistoryFilter.all,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '未接',
                    selected: filter == HistoryFilter.missed,
                    onSelected: () => ref.read(historyFilterProvider.notifier).state = HistoryFilter.missed,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '呼出',
                    selected: filter == HistoryFilter.out,
                    onSelected: () => ref.read(historyFilterProvider.notifier).state = HistoryFilter.out,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '呼入',
                    selected: filter == HistoryFilter.incoming,
                    onSelected: () => ref.read(historyFilterProvider.notifier).state = HistoryFilter.incoming,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: callsAsync.when(
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
          data: (allList) {
            final filteredList = allList.where((c) {
              switch (filter) {
                case HistoryFilter.all:
                  return true;
                case HistoryFilter.missed:
                  return c.direction == 'missed';
                case HistoryFilter.out:
                  return c.direction == 'out';
                case HistoryFilter.incoming:
                  return c.direction == 'in';
              }
            }).toList();

            return RefreshIndicator(
              onRefresh: () => _refresh(context, ref),
              child: allList.isEmpty
                  ? const _EmptyState()
                  : filteredList.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: 300,
                              child: Center(
                                child: Text(
                                  '无对应分类通话记录',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: scheme.onSurfaceMuted,
                                      ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          key: const Key('history-list'),
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: filteredList.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _CallRow(
                            call: filteredList[i],
                            onDelete: () async {
                              await ref
                                  .read(syncRepositoryProvider)
                                  .deleteLocal(filteredList[i].id);
                            },
                            onCallBack: () => _quickCallBack(context, ref, filteredList[i].remoteNumber),
                          ),
                        ),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        color: selected ? scheme.onPrimary : scheme.onSurfaceMuted,
      ),
      selectedColor: scheme.primary,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? scheme.primary : Colors.transparent,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
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
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.phone_missed_outlined,
                  size: 48,
                  color: scheme.tertiary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '暂无通话',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '去拨号开始第一通电话',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceMuted,
                    ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: () => _goDialpad(context),
                icon: const Icon(Icons.dialpad, size: 20),
                label: const Text('去拨号'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 单行通话记录：卡片化圆角容器、优雅头像徽标、状态标签、回拨按钮
class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.call,
    required this.onDelete,
    required this.onCallBack,
  });

  final LocalCall call;
  final Future<void> Function() onDelete;
  final VoidCallback onCallBack;

  IconData get _directionIcon => switch (call.direction) {
        'in' => Icons.call_received,
        'missed' => Icons.call_missed_outgoing,
        _ => Icons.call_made,
      };

  Color _iconColor(ColorScheme scheme) {
    if (call.direction == 'missed') return scheme.error;
    if (call.direction == 'in') return scheme.success;
    return scheme.tertiary;
  }

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

  String get _dispositionLabel => switch (call.disposition) {
        'answered' => '已接听',
        'busy' => '对方忙',
        'no_answer' => '未接听',
        'failed' => '呼叫失败',
        _ => '',
      };

  Future<bool?> _confirmDelete(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这条通话记录?'),
        content: Text('将删除与分机 ${call.remoteNumber} 的本次记录。'),
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
    final iconColor = _iconColor(scheme);

    return Dismissible(
      key: ValueKey('call-${call.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => onDelete(),
      background: Container(
        decoration: BoxDecoration(
          color: scheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('删除记录', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Icon(Icons.delete_outline, color: Colors.white),
          ],
        ),
      ),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: scheme.outline.withValues(alpha: 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onCallBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // 头像与状态角标
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          call.remoteNumber.isNotEmpty ? call.remoteNumber[0] : '#',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _directionIcon,
                          size: 14,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // 核心信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              call.remoteNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: missed ? scheme.error : scheme.onSurface,
                              ),
                            ),
                          ),
                          if (_dispositionLabel.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (missed ? scheme.error : scheme.onSurfaceMuted).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _dispositionLabel,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  color: missed ? scheme.error : scheme.onSurfaceMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _timeLabel(DateTime.now()),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceMuted,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (call.durationSec > 0) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Text('·', style: TextStyle(color: scheme.onSurfaceMuted)),
                            ),
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

                // 未同步小点
                if (!call.pushed)
                  Semantics(
                    label: '未同步',
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Tooltip(
                        message: '未同步到云端',
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: scheme.tertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 回拨快速动作按钮
                IconButton.filledTonal(
                  iconSize: 20,
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.surfaceContainerHighest,
                    foregroundColor: scheme.onSurface,
                  ),
                  icon: const Icon(Icons.call_outlined),
                  onPressed: onCallBack,
                  tooltip: '回拨 ${call.remoteNumber}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
