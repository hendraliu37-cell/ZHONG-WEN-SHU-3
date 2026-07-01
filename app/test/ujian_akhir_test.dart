import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/models/vocab.dart';
import 'package:zhongwen_shu/overlays/ujian_akhir.dart';
import 'package:zhongwen_shu/state/app_controller.dart';
import 'package:zhongwen_shu/theme/tokens.dart';
import 'package:zhongwen_shu/theme/zws_theme.dart';

VocabEntry _vocab({
  required String hanzi,
  required String pinyin,
  required String meaning,
  required int tone,
}) => VocabEntry(
  simplified: hanzi,
  traditional: hanzi,
  pinyin: pinyin,
  meaning: meaning,
  tone: tone,
);

void main() {
  testWidgets('final exam keeps mixed question types for small decks', (
    tester,
  ) async {
    final c = AppController();
    c.cards[1] = _vocab(hanzi: '吃', pinyin: 'chī', meaning: 'makan', tone: 1);
    c.cards[2] = _vocab(hanzi: '好', pinyin: 'hǎo', meaning: 'baik', tone: 3);

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(home: UjianAkhirOverlay(controller: c)),
      ),
    );

    final seen = <String>{};
    for (var i = 0; i < 10; i++) {
      await tester.pumpAndSettle();
      if (find.text('Nilai Ujian Akhir').evaluate().isNotEmpty) break;

      if (find.textContaining('PILIH ARTI').evaluate().isNotEmpty) {
        seen.add('mc');
        final option = find.text('makan').evaluate().isNotEmpty
            ? find.text('makan')
            : find.text('baik');
        await tester.tap(option);
      } else if (find.textContaining('TULIS HANZI').evaluate().isNotEmpty) {
        seen.add('spell');
        await tester.enterText(find.byType(TextField), 'x');
        await tester.tap(find.text('Periksa'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Periksa'));
      } else if (find.textContaining('NADA SUKU').evaluate().isNotEmpty) {
        seen.add('tone');
        await tester.tap(find.textContaining('Nada Pertama').first);
      } else {
        fail('Unknown final exam question type');
      }
    }

    expect(seen, containsAll(['mc', 'spell', 'tone']));
    expect(find.text('Nilai Ujian Akhir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
