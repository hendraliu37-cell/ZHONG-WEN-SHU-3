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
}
