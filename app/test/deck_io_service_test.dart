import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/models/vocab.dart';
import 'package:zhongwen_shu/services/deck_io_service.dart';

void main() {
  test('imports headerless Anki-style TSV without dropping first card', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '你好\thalo\tnǐ hǎo\n好吃\tenak\thǎochī\t好喫',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '你好');
    expect(cards.first.meaning, 'halo');
    expect(cards.first.pinyin, 'nǐ hǎo');
    expect(cards.last.simplified, '好吃');
    expect(cards.last.traditional, '好吃');
  });

  test('imports Quizlet-style term and definition headers', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'term,definition,pinyin\n谢谢,terima kasih,xièxie',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(1));
    expect(cards.single.simplified, '谢谢');
    expect(cards.single.meaning, 'terima kasih');
    expect(cards.single.pinyin, 'xièxie');
  });

  test('imports common Chinese Pinyin English headers', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'Chinese,Pinyin,English\n吃,chī,eat\n学习,xué xí,study',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '吃');
    expect(cards.first.pinyin, 'chī');
    expect(cards.first.meaning, 'eat');
    expect(cards.last.simplified, '学习');
    expect(cards.last.pinyin, 'xué xí');
    expect(cards.last.meaning, 'study');
  });

  test('imports semicolon CSV exported by spreadsheet locales', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'Chinese;Pinyin;English\n吃;chi1;makan\n喝;he1;minum',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '吃');
    expect(cards.first.meaning, 'makan');
    expect(cards.last.simplified, '喝');
    expect(cards.last.meaning, 'minum');
  });

  test('ignores Excel sep directive before localized headers', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'sep=;\n汉字;拼音;释义\n吃;chi1;makan\n喝;he1;minum',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.map((c) => c.simplified), ['吃', '喝']);
    expect(cards.first.meaning, 'makan');
  });

  test('imports UTF-8 BOM files with Excel separator directive', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '\uFEFFsep=;\n汉字;拼音;释义\n吃;chi1;makan\n喝;he1;minum',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.map((c) => c.simplified), ['吃', '喝']);
    expect(cards.last.meaning, 'minum');
  });

  test('imports UTF-8 BOM files with normal headers', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '\uFEFFChinese,Pinyin,English\n吃,chi1,makan\n喝,he1,minum',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '吃');
    expect(cards.first.pinyin, 'chi1');
    expect(cards.first.meaning, 'makan');
  });

  test('imports common Anki Mandarin expression headers', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'Expression,Reading,Meaning\n学习,xue2 xi2,belajar\n吃饭,chi1 fan4,makan',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '学习');
    expect(cards.first.pinyin, 'xue2 xi2');
    expect(cards.first.meaning, 'belajar');
    expect(cards.last.simplified, '吃饭');
    expect(cards.last.meaning, 'makan');
  });

  test('imports character pronunciation gloss headers', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'Characters,Pronunciation,Gloss\n水,shui3,air\n老师,lao3 shi1,guru',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '水');
    expect(cards.first.pinyin, 'shui3');
    expect(cards.first.meaning, 'air');
    expect(cards.last.simplified, '老师');
    expect(cards.last.meaning, 'guru');
  });

  test('imports common Simplified Chinese header names', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'Simplified Chinese,Traditional Chinese,Pinyin,English Definition\n学习,學習,xue2 xi2,belajar',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(1));
    expect(cards.single.simplified, '学习');
    expect(cards.single.traditional, '學習');
    expect(cards.single.pinyin, 'xue2 xi2');
    expect(cards.single.meaning, 'belajar');
  });

  test('imports Mandarin-language headers without creating header cards', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '汉字,拼音,释义,繁體,声调\n吃,chī,makan,吃,1\n学习,xuéxí,belajar,學習,2',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '吃');
    expect(cards.first.pinyin, 'chī');
    expect(cards.first.meaning, 'makan');
    expect(cards.first.tone, 1);
    expect(cards.last.simplified, '学习');
    expect(cards.last.traditional, '學習');
    expect(cards.last.meaning, 'belajar');
  });

  test('imports decimal numeric levels from spreadsheets', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'Chinese,Pinyin,English,tone,hsk,tocfl\n看,kan4,lihat,4.0,2.0,3.0',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(1));
    expect(cards.single.tone, 4);
    expect(cards.single.hskLevel, 2);
    expect(cards.single.tocflLevel, 3);
  });

  test(
    'imports Indonesian-front headerless cards by swapping Chinese back',
    () {
      final service = DeckIoService();
      final rows = service.readDelimitedForTest('makan\t吃\tchī');
      final cards = service.rowsToCardsForTest(rows);

      expect(cards, hasLength(1));
      expect(cards.single.simplified, '吃');
      expect(cards.single.meaning, 'makan');
    },
  );

  test('imports front/back headers when Chinese is on the back side', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'Front,Back,Pinyin\nmakan,\u5403,chi1\nhalo,\u4f60\u597d,ni3 hao3',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '\u5403');
    expect(cards.first.traditional, '\u5403');
    expect(cards.first.meaning, 'makan');
    expect(cards.first.pinyin, 'chi1');
    expect(cards.last.simplified, '\u4f60\u597d');
    expect(cards.last.meaning, 'halo');
  });

  test('ignores latin-only flashcard rows in Chinese deck imports', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'Term,Definition\nhello,greeting\nmakan,\u5403',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(1));
    expect(cards.single.simplified, '\u5403');
    expect(cards.single.meaning, 'makan');
  });

  test('parses a single headerless card row', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest('吃\tmakan\tchī');
    final result = service.importRowsForTest(rows, sourceName: 'single.tsv');

    expect(result.sourceName, 'single.tsv');
    expect(result.cards, hasLength(1));
    expect(result.cards.single.simplified, '吃');
    expect(result.cards.single.meaning, 'makan');
    expect(result.cards.single.pinyin, 'chī');
  });

  test('imports headerless hanzi pinyin meaning order', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '吃\tchī\tmakan\n你好\tnǐ hǎo\thalo',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '吃');
    expect(cards.first.pinyin, 'chī');
    expect(cards.first.meaning, 'makan');
    expect(cards.last.simplified, '你好');
    expect(cards.last.pinyin, 'nǐ hǎo');
    expect(cards.last.meaning, 'halo');
  });

  test('headerless notes column is not mistaken for traditional Hanzi', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '\u5403\tchi1\tmakan\tcommon verb\n'
      '\u5b66\u4e60\txue2 xi2\tbelajar\t\u5b78\u7fd2',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '\u5403');
    expect(cards.first.traditional, '\u5403');
    expect(cards.first.meaning, 'makan');
    expect(cards.last.simplified, '\u5b66\u4e60');
    expect(cards.last.traditional, '\u5b78\u7fd2');
  });

  test('imports common Anki extra field as example notes', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      'Expression,Reading,Meaning,Extra\n'
      '\u5403,chi1,makan,kata kerja umum',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(1));
    expect(cards.single.simplified, '\u5403');
    expect(cards.single.exampleId, 'kata kerja umum');
  });

  test('imports Anki exports with metadata directives and columns', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '#separator:tab\n'
      '#html:false\n'
      '#notetype column:1\n'
      '#deck column:2\n'
      '#tags column:6\n'
      'Basic\tMandarin\t\u4f60\u597d\tn\u01d0 h\u01ceo\thalo\tgreeting\n'
      'Basic\tMandarin\t\u5b66\u4e60\txu\u00e9x\u00ed\tbelajar\tverb',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '\u4f60\u597d');
    expect(cards.first.pinyin, 'n\u01d0 h\u01ceo');
    expect(cards.first.meaning, 'halo');
    expect(cards.last.simplified, '\u5b66\u4e60');
    expect(cards.last.meaning, 'belajar');
  });

  test('imports Anki semicolon separator directive', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '#separator:semicolon\n'
      '#html:false\n'
      'Expression;Reading;Meaning\n'
      '\u5403;chi1;makan\n'
      '\u559d;he1;minum',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(2));
    expect(cards.first.simplified, '\u5403');
    expect(cards.first.pinyin, 'chi1');
    expect(cards.first.meaning, 'makan');
    expect(cards.last.simplified, '\u559d');
    expect(cards.last.meaning, 'minum');
  });

  test('imports Anki HTML fields without keeping markup', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '#separator:tab\n'
      '#html:true\n'
      'Expression\tReading\tMeaning\tExtra\n'
      '<b>\u5403</b>\t<span>chi1</span>\tmakan<br>eat\t'
      '<div>kata&nbsp;kerja &amp; umum</div>',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(1));
    expect(cards.single.simplified, '\u5403');
    expect(cards.single.pinyin, 'chi1');
    expect(cards.single.meaning, 'makan / eat');
    expect(cards.single.exampleId, 'kata kerja & umum');
  });

  test('imports Anki HTML numeric entities as Hanzi', () {
    final service = DeckIoService();
    final rows = service.readDelimitedForTest(
      '#separator:tab\n'
      '#html:true\n'
      'Expression\tReading\tMeaning\tExtra\n'
      '<b>&#20320;&#22909;</b>\tni3 hao3\thalo\t'
      '&#x4F60;&#x597D; &apos;umum&apos;',
    );
    final cards = service.rowsToCardsForTest(rows);

    expect(cards, hasLength(1));
    expect(cards.single.simplified, '\u4f60\u597d');
    expect(cards.single.pinyin, 'ni3 hao3');
    expect(cards.single.meaning, 'halo');
    expect(cards.single.exampleId, "\u4f60\u597d 'umum'");
  });

  test('roundtrips exported Excel rows back into cards', () {
    final service = DeckIoService();
    final bytes = service.buildExcelForTest([
      const VocabEntry(
        simplified: '学习',
        traditional: '學習',
        pinyin: 'xue2 xi2',
        zhuyin: 'ㄒㄩㄝˊ ㄒㄧˊ',
        meaning: 'belajar / studi',
        exampleS: '我学习中文。',
        exampleT: '我學習中文。',
        exampleId: 'Saya belajar Mandarin.',
        tone: 2,
        hskLevel: 1,
        tocflLevel: 2,
      ),
    ]);

    final rows = service.readExcelForTest(bytes);
    final cards = service.rowsToCardsForTest(rows);

    expect(rows.first.take(5), [
      'simplified',
      'traditional',
      'pinyin',
      'zhuyin',
      'meaning',
    ]);
    expect(cards, hasLength(1));
    expect(cards.single.simplified, '学习');
    expect(cards.single.traditional, '學習');
    expect(cards.single.pinyin, 'xue2 xi2');
    expect(cards.single.meaning, 'belajar / studi');
    expect(cards.single.hskLevel, 1);
    expect(cards.single.tocflLevel, 2);
  });
}
