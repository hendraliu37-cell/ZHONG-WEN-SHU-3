import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhongwen_shu/app_shell.dart';
import 'package:zhongwen_shu/state/app_controller.dart';
import 'package:zhongwen_shu/theme/tokens.dart';
import 'package:zhongwen_shu/theme/zws_theme.dart';
import 'package:zhongwen_shu/widgets/ico.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('leaderboard overlay back button closes the overlay', (
    tester,
  ) async {
    final c = AppController()..leaderOpen = true;

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(
          home: Scaffold(body: AppShell(controller: c)),
        ),
      ),
    );

    expect(c.leaderOpen, isTrue);
    await tester.tap(find.byIcon(ZwsIcons.back).first);
    await tester.pumpAndSettle();

    expect(c.leaderOpen, isFalse);
  });
}
