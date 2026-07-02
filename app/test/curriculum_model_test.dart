import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/models/curriculum.dart';

void main() {
  test('DailyMaterial parser keeps valid rows from loose server payloads', () {
    final material = DailyMaterial.fromJson({
      'topic': 123,
      'vocab': [
        {'hanzi': 456, 'pinyin': null, 'meaning': ' angka '},
        'bad-row',
        {'hanzi': '', 'meaning': ''},
      ],
      'sentences': [' 我喜欢中文。 ', null, ''],
      'exercise': 789,
    });

    expect(material.topic, '123');
    expect(material.vocab, hasLength(1));
    expect(material.vocab.single.hanzi, '456');
    expect(material.vocab.single.pinyin, '');
    expect(material.vocab.single.meaning, 'angka');
    expect(material.sentences, ['我喜欢中文。']);
    expect(material.exercise, '789');
    expect(material.summary, '456');
  });

  test('DailyMaterial parser tolerates non-list containers', () {
    final material = DailyMaterial.fromJson({
      'topic': 'Kosong',
      'vocab': {'hanzi': '吃'},
      'sentences': '不是列表',
      'exercise': null,
    });

    expect(material.topic, 'Kosong');
    expect(material.vocab, isEmpty);
    expect(material.sentences, isEmpty);
    expect(material.exercise, '');
    expect(material.summary, 'Kosong');
  });
}
