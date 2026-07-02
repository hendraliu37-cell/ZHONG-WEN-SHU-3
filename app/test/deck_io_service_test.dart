import 'package:flutter_test/flutter_test.dart';
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
}
