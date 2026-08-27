import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_terminal/core/theme.dart';
import 'package:sip_terminal/data/app_db.dart';
import 'package:sip_terminal/data/providers.dart';
import 'package:sip_terminal/data/sync_repository.dart';
import 'package:sip_terminal/features/history/history_page.dart';

/// 不触碰真实 DB 的假仓库：只覆写页面用到的入口。
class _FakeRepo extends SyncRepository {
  _FakeRepo({this.failPull = false})
    : super(
        AppDb.forTest(NativeDatabase.memory()),
        poster: (_) async => 1,
        fetcher: ({beforeTime, beforeId}) async =>
            (items: const <ServerCall>[], cursor: null),
        deleter: (_) async {},
      );

  final bool failPull;
  final deletedIds = <int>[];

  List<LocalCall> rows = const [];

  @override
  Future<void> pushPending() async {}

  @override
  Future<void> pullMerge() async {
    if (failPull) throw Exception('network down');
  }

  @override
  Future<void> deleteLocal(int localId) async {
    deletedIds.add(localId);
  }

  @override
  Stream<List<LocalCall>> watchAll() => Stream.value(rows);
}

LocalCall _row({
  required int id,
  String number = '1002',
  String direction = 'out',
  String disposition = 'answered',
  DateTime? startedAt,
  int durationSec = 0,
  bool pushed = true,
}) => LocalCall(
  id: id,
  remoteNumber: number,
  direction: direction,
  disposition: disposition,
  startedAt: startedAt ?? DateTime.now(),
  durationSec: durationSec,
  pushed: pushed,
);

Future<void> _pump(WidgetTester tester, _FakeRepo repo) async {
  final container = ProviderContainer(
    overrides: [syncRepositoryProvider.overrideWithValue(repo)],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildLightTheme(), home: const HistoryPage()),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  testWidgets('空列表 → 空状态与去拨号按钮', (tester) async {
    await _pump(tester, _FakeRepo());

    expect(find.byKey(const Key('history-empty')), findsOneWidget);
    expect(find.text('暂无通话'), findsOneWidget);
    expect(find.text('去拨号开始第一通电话'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '去拨号'), findsOneWidget);
  });

  testWidgets('两行记录：方向图标、时长文案与今天/昨天相对时间', (tester) async {
    final repo = _FakeRepo()
      ..rows = [
        _row(
          id: 1,
          number: '1002',
          direction: 'missed',
          disposition: 'no_answer',
          startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          pushed: false,
        ),
        _row(
          id: 2,
          number: '1003',
          direction: 'out',
          disposition: 'answered',
          startedAt: DateTime.now().subtract(const Duration(days: 1)),
          durationSec: 83,
        ),
      ];
    await _pump(tester, repo);

    expect(find.byKey(const Key('history-list')), findsOneWidget);
    // 方向图标：missed → call_missed_outgoing，out → call_made
    expect(find.byIcon(Icons.call_missed_outgoing), findsOneWidget);
    expect(find.byIcon(Icons.call_made), findsOneWidget);
    // 未同步小圆点只在 pushed=false 的行上（Semantics 标注）
    expect(
      find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == '未同步',
      ),
      findsOneWidget,
    );
    // 相对时间与时长
    expect(find.textContaining('今天'), findsOneWidget);
    expect(find.textContaining('昨天'), findsOneWidget);
    expect(find.text('1分23秒'), findsOneWidget);
  });

  testWidgets('滑动删除 → 确认框取消 → 行保留不删除', (tester) async {
    final repo = _FakeRepo()
      ..rows = [_row(id: 1, number: '1002'), _row(id: 2, number: '1003')];
    await _pump(tester, repo);

    await tester.drag(find.text('1002'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('删除这条通话记录?'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(find.text('1002'), findsOneWidget);
    expect(repo.deletedIds, isEmpty);
  });

  testWidgets('滑动删除 → 确认删除 → deleteLocal 被调用', (tester) async {
    final repo = _FakeRepo()
      ..rows = [_row(id: 1, number: '1002'), _row(id: 2, number: '1003')];
    await _pump(tester, repo);

    await tester.drag(find.text('1002'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(repo.deletedIds, [1]);
  });

  testWidgets('下拉刷新失败 → SnackBar 带重试按钮', (tester) async {
    await _pump(tester, _FakeRepo(failPull: true));

    await tester.fling(find.text('暂无通话'), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('刷新失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
  });
}
