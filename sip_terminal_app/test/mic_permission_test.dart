import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_terminal/core/mic_permission.dart';

class _Probe extends StatelessWidget {
  const _Probe({required this.onResult});

  final ValueChanged<bool> onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () async {
            final ok = await ensureMicPermission(context);
            onResult(ok);
          },
          child: const Text('通话'),
        ),
      ),
    );
  }
}

Future<List<bool>> _pump(WidgetTester tester) async {
  final results = <bool>[];
  await tester.pumpWidget(MaterialApp(home: _Probe(onResult: results.add)));
  return results;
}

void main() {
  tearDown(MicPermission.reset);

  testWidgets('已授权 → 直接通过，不弹对话框', (tester) async {
    MicPermission.handler = () async => MicPermissionResult.granted;
    final results = await _pump(tester);

    await tester.tap(find.text('通话'));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('本次拒绝(denied) → 返回 false，不弹对话框', (tester) async {
    MicPermission.handler = () async => MicPermissionResult.denied;
    var settingsOpens = 0;
    MicPermission.settingsOpener = () async => settingsOpens++;
    final results = await _pump(tester);

    await tester.tap(find.text('通话'));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(find.byType(AlertDialog), findsNothing);
    expect(settingsOpens, 0);
  });

  testWidgets('永久拒绝 → 弹引导对话框；取消 → false 且不去设置', (tester) async {
    MicPermission.handler = () async => MicPermissionResult.permanentlyDenied;
    var settingsOpens = 0;
    MicPermission.settingsOpener = () async => settingsOpens++;
    final results = await _pump(tester);

    await tester.tap(find.text('通话'));
    await tester.pumpAndSettle();

    expect(find.text('需要麦克风权限才能通话'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('去设置'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(settingsOpens, 0);
  });

  testWidgets('永久拒绝 → 去设置 → 调用 openAppSettings', (tester) async {
    MicPermission.handler = () async => MicPermissionResult.permanentlyDenied;
    var settingsOpens = 0;
    MicPermission.settingsOpener = () async => settingsOpens++;
    final results = await _pump(tester);

    await tester.tap(find.text('通话'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('去设置'));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(settingsOpens, 1);
  });
}
