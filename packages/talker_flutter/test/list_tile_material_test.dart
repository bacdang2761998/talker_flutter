import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/src/ui/talker_actions/talker_actions_bottom_sheet.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// ListTile nằm dưới một box có màu nền phải có Material riêng, nếu không
/// Flutter assert "ListTile background color or ink splashes may be invisible".
void main() {
  const theme = TalkerScreenTheme();

  Future<void> pump(WidgetTester tester, Widget child) {
    return tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  }

  testWidgets('sheet Actions không assert ListTile', (tester) async {
    await pump(
      tester,
      TalkerActionsBottomSheet(
        talkerScreenTheme: theme,
        actions: [
          TalkerActionItem(onTap: () {}, title: 'Share', icon: Icons.share),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(ListTile), findsOneWidget);
  });
}
