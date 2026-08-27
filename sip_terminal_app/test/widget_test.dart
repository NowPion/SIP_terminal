import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sip_terminal/core/theme.dart';

void main() {
  testWidgets('themed placeholder renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: Center(child: Text('SIP Terminal')),
        ),
      ),
    );
    expect(find.text('SIP Terminal'), findsOneWidget);
  });
}
