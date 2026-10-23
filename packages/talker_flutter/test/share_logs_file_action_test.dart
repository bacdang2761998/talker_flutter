import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// canShareLogsFile: false hides the "Share logs file" action; default keeps
/// the upstream action list.
void main() {
  Future<void> openActions(WidgetTester tester, {bool? canShare}) async {
    final talker = Talker(settings: TalkerSettings(useConsoleLogs: false));
    await tester.pumpWidget(
      MaterialApp(
        home: canShare == null
            ? TalkerScreen(talker: talker)
            : TalkerScreen(talker: talker, canShareLogsFile: canShare),
      ),
    );
    await tester.tap(find.byIcon(Icons.menu_rounded));
    await tester.pumpAndSettle();
  }

  testWidgets('default shows "Share logs file"', (tester) async {
    await openActions(tester);
    expect(find.text('Share logs file'), findsOneWidget);
  });

  testWidgets('canShareLogsFile: false hides it, keeps the rest',
      (tester) async {
    await openActions(tester, canShare: false);
    expect(find.text('Share logs file'), findsNothing);
    expect(find.text('Clean history'), findsOneWidget);
  });
}
