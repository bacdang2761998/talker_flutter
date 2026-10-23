import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Bật/tắt một setting của Talker không được làm mất các key package đã đăng
/// ký (TalkerSettings.copyWith không mang theo registeredKeys).
void main() {
  for (final title in ['Use console logs', 'Use history']) {
    testWidgets('tắt rồi bật "$title" vẫn giữ Packages settings',
        (tester) async {
      final talker = Talker()
        ..settings
            .registerKeys([TalkerKey.httpRequest, TalkerKey.httpResponse]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TalkerSettingsBottomSheet(
              talkerScreenTheme: const TalkerScreenTheme(),
              talker: ValueNotifier(talker),
              customSettings: const [],
            ),
          ),
        ),
      );

      final toggle = find.descendant(
        of: find.widgetWithText(ListTile, title),
        matching: find.byType(CupertinoSwitch),
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(toggle);
        await tester.pumpAndSettle();
      }

      expect(
        talker.settings.registeredKeys,
        [TalkerKey.httpRequest, TalkerKey.httpResponse],
      );
      expect(find.text(TalkerKey.httpRequest), findsOneWidget);
      expect(find.text(TalkerKey.httpResponse), findsOneWidget);
    });
  }
}
