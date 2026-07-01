import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/models/vocab.dart';

void main() {
  test('splits and deduplicates Pleco-style meanings', () {
    const entry = VocabEntry(
      simplified: '你好',
      traditional: '你好',
      pinyin: 'ni hao',
      zhuyin: 'ㄋㄧˇ ㄏㄠˇ',
      meaning: 'halo / hai; apa kabar, halo',
    );

    expect(entry.primaryMeaning, 'halo');
    expect(entry.alternativeMeanings, ['hai', 'apa kabar']);
    expect(entry.meaningPreview, 'halo / hai / apa kabar');
  });

  test('matches any stored meaning alias', () {
    const entry = VocabEntry(
      simplified: '谢谢',
      traditional: '謝謝',
      pinyin: 'xiexie',
      zhuyin: 'ㄒㄧㄝˋ ㄒㄧㄝ˙',
      meaning: 'terima kasih / makasih',
    );

    expect(entry.matchesMeaning('Terima kasih'), isTrue);
    expect(entry.matchesMeaning('makasih'), isTrue);
    expect(entry.matchesMeaning('halo'), isFalse);
  });

  test('normalizes obsolete traditional variants when loading cards', () {
    final entry = VocabEntry.fromJson({
      's': '好吃',
      't': '好喫',
      'py': 'hǎochī',
      'm': 'enak',
      'ext': '他爲了朋友在城裏過着忙碌生活。',
    });

    expect(entry.traditional, '好吃');
    expect(entry.exampleT, '他為了朋友在城裡過著忙碌生活。');
  });
}
