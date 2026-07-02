import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhongwen_shu/config.dart';
import 'package:zhongwen_shu/screens/auth.dart';
import 'package:zhongwen_shu/state/app_controller.dart';
import 'package:zhongwen_shu/theme/tokens.dart';
import 'package:zhongwen_shu/theme/zws_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUp(() {
    zwsSupabaseReady = false;
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          recordChannel,
          (MethodCall call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
    zwsSupabaseReady = false;
  });

  testWidgets('password field can be shown and hidden again', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: zwsThemeData(ZwsTokens.light),
        home: ZwsTheme(
          tokens: ZwsTokens.light,
          child: Scaffold(body: AuthScreen(controller: AppController())),
        ),
      ),
    );

    TextField passwordField() =>
        tester.widgetList<TextField>(find.byType(TextField)).last;

    expect(passwordField().obscureText, isTrue);
    await tester.tap(find.byTooltip('Tampilkan kata sandi'));
    await tester.pump();
    expect(passwordField().obscureText, isFalse);

    await tester.tap(find.byTooltip('Sembunyikan kata sandi'));
    await tester.pump();
    expect(passwordField().obscureText, isTrue);
  });
}
