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
