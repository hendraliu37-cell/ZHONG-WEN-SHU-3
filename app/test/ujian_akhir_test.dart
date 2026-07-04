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
        expect(find.text('Lanjut'), findsOneWidget);
        await tester.tap(find.text('Lanjut'));
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

  testWidgets('final exam question count follows all source cards', (
    tester,
  ) async {
    final c = AppController();
    for (var i = 1; i <= 25; i++) {
      c.cards[i] = _vocab(
        hanzi: '字$i',
        pinyin: 'zi$i',
        meaning: 'arti $i',
        tone: (i % 4) + 1,
      );
    }

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(home: UjianAkhirOverlay(controller: c)),
      ),
    );

    expect(find.text('Soal 1/25'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('final exam supports neutral tone questions', (tester) async {
    final c = AppController();
    c.cards[1] = _vocab(
      hanzi: '\u5417',
      pinyin: 'ma5',
      meaning: 'partikel tanya',
      tone: 5,
    );

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(home: UjianAkhirOverlay(controller: c)),
      ),
    );

    var sawNeutralTone = false;
    for (var i = 0; i < 6; i++) {
      await tester.pumpAndSettle();
      if (find.text('Nilai Ujian Akhir').evaluate().isNotEmpty) break;
      sawNeutralTone =
          await _answerNeutralToneExamQuestion(tester) || sawNeutralTone;
    }

    expect(sawNeutralTone, isTrue);
    expect(find.text('Nilai Ujian Akhir'), findsOneWidget);
    expect(c.lastUjianAkhirPct, 100);
    expect(tester.takeException(), isNull);
  });

  testWidgets('final exam back confirms after progress', (tester) async {
    final c = AppController()..sub = 'ujian_akhir';
    for (var i = 1; i <= 4; i++) {
      c.cards[i] = _vocab(
        hanzi: '字$i',
        pinyin: 'zi$i',
        meaning: 'arti $i',
        tone: (i % 4) + 1,
      );
    }

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(home: UjianAkhirOverlay(controller: c)),
      ),
    );

    await _answerCurrentQuestion(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari ujian?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(c.sub, 'ujian_akhir');

    await tester.tap(find.byIcon(Icons.arrow_back).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(c.sub, isNull);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _answerCurrentQuestion(WidgetTester tester) async {
  if (find.textContaining('PILIH ARTI').evaluate().isNotEmpty) {
    await tester.tap(find.textContaining('arti ').first);
  } else if (find.textContaining('TULIS HANZI').evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextField), 'x');
    await tester.tap(find.text('Periksa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut'));
  } else if (find.textContaining('NADA SUKU').evaluate().isNotEmpty) {
    await tester.tap(find.textContaining('Nada ').first);
  } else {
    fail('Unknown final exam question type');
  }
}

Future<bool> _answerNeutralToneExamQuestion(WidgetTester tester) async {
  if (find.textContaining('PILIH ARTI').evaluate().isNotEmpty) {
    await tester.tap(find.text('partikel tanya'));
    return false;
  }
  if (find.textContaining('TULIS HANZI').evaluate().isNotEmpty) {
    await tester.enterText(find.byType(TextField), '\u5417');
    await tester.tap(find.text('Periksa'));
    await tester.pumpAndSettle();
    expect(find.text('Lanjut'), findsOneWidget);
    await tester.tap(find.text('Lanjut'));
    return false;
  }
  if (find.textContaining('NADA SUKU').evaluate().isNotEmpty) {
    expect(find.textContaining('Nada Netral'), findsOneWidget);
    await tester.tap(find.textContaining('Nada Netral').first);
    return true;
  }
  fail('Unknown final exam question type');
}
