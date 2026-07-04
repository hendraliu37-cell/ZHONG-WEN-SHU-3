import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhongwen_shu/models/vocab.dart';
import 'package:zhongwen_shu/overlays/tone_game.dart';
import 'package:zhongwen_shu/state/app_controller.dart';
import 'package:zhongwen_shu/theme/tokens.dart';
import 'package:zhongwen_shu/theme/zws_theme.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('tone game can answer neutral tone cards', (tester) async {
    final c = AppController();
    c.cards[1] = const VocabEntry(
      simplified: '\u5417',
      traditional: '\u5417',
      pinyin: 'ma5',
      meaning: 'partikel tanya',
      tone: 5,
    );
    c.qCount = 1;
    c.startTone();

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(
          home: ListenableBuilder(
            listenable: c,
            builder: (context, _) =>
                Scaffold(body: ToneGameOverlay(controller: c, desktop: false)),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('5'), findsOneWidget);

    await tester.tap(find.text('5'));
    await tester.pump();

    expect(c.tonePicked, 5);
    expect(c.toneScore, 1);
    expect(find.text('Lihat hasil'), findsOneWidget);

    await tester.tap(find.text('Lihat hasil'));
    await tester.pumpAndSettle();

    expect(find.text('Mantap!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
