import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhongwen_shu/screens/guru.dart';
import 'package:zhongwen_shu/state/app_controller.dart';
import 'package:zhongwen_shu/theme/tokens.dart';
import 'package:zhongwen_shu/theme/zws_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('private Guru chat suggests Guru mention after typing @', (
    tester,
  ) async {
    final c = AppController();

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 420,
              height: 720,
              child: GuruScreen(controller: c, desktop: false),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).last, '@');
    await tester.pump();

    expect(find.text('@Guru'), findsOneWidget);

    await tester.tap(find.text('@Guru'));
    await tester.pump();

    expect(c.chatInput, '@Guru ');
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      '@Guru ',
    );
  });
}
