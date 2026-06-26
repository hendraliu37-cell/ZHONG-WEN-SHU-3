import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/models/vocab.dart';
import 'package:zhongwen_shu/services/dictionary_service.dart';

void main() {
  final dict = DictionaryService()
    ..load(const [
      VocabEntry(
          simplified: '我', traditional: '我', pinyin: 'wǒ', meaning: 'saya'),
      VocabEntry(
          simplified: '喜欢',
          traditional: '喜歡',
          pinyin: 'xǐhuān',
          meaning: 'suka',
          hskLevel: 1),
      VocabEntry(
          simplified: '中文',
          traditional: '中文',
          pinyin: 'zhōngwén',
          meaning: 'bahasa Mandarin',
          hskLevel: 2),
    ]);

  group('DictionaryService.segment', () {
    test('greedy longest-match splits a known sentence into words', () {
      final toks = dict.segment('我喜欢中文');
      expect(toks.map((t) => t.hanzi).toList(), ['我', '喜欢', '中文']);
      expect(toks[1].meaning, 'suka'); // multi-char word matched, not 喜+欢
      expect(toks[1].hsk, 1);
      expect(toks[2].pinyin, 'zhōngwén');
    });

    test('unknown characters fall back to single-char tokens', () {
      final toks = dict.segment('我爱中文');
      expect(toks.map((t) => t.hanzi).toList(), ['我', '爱', '中文']);
      expect(toks[1].meaning, ''); // 爱 unknown → hanzi only
    });

    test('skips punctuation and latin/space runs', () {
      final toks = dict.segment('我, 喜欢 ok。中文!');
      expect(toks.map((t) => t.hanzi).toList(), ['我', '喜欢', '中文']);
    });

    test('empty / non-CJK input yields no tokens', () {
      expect(dict.segment('hello world'), isEmpty);
      expect(dict.segment(''), isEmpty);
    });
  });
}
