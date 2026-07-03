import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/models/curriculum.dart';
import 'package:zhongwen_shu/services/curriculum_service.dart';

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

  test('DailyMaterial parser accepts JSON string list fields', () {
    final material = DailyMaterial.fromJson({
      'topic': 'Belanja',
      'vocab': '[{"hanzi":"买","pinyin":"mai3","meaning":"membeli"},"bad-row"]',
      'sentences': '[" 我买水果。 ", "", null]',
      'exercise': 'Buat kalimat.',
    });

    expect(material.vocab, hasLength(1));
    expect(material.vocab.single.hanzi, '买');
    expect(material.sentences, ['我买水果。']);
  });

  test('curriculum response parser picks the first usable material', () {
    final material = parseCurriculumResponse({
      'cached': true,
      'materials': [
        'bad-row',
        {'topic': '', 'vocab': [], 'sentences': [], 'exercise': ''},
        {
          'topic': 'Makan',
          'vocab': [
            {'hanzi': '\u5403', 'pinyin': 'chi1', 'meaning': 'makan'},
          ],
          'sentences': ['\u6211\u5403\u996d\u3002'],
          'exercise': 'Buat satu kalimat.',
        },
      ],
    });

    expect(material, isNotNull);
    expect(material!.topic, 'Makan');
    expect(material.vocab.single.hanzi, '\u5403');
  });

  test(
    'curriculum response parser accepts raw JSON string and singular material',
    () {
      final material = parseCurriculumResponse(
        '{"material":{"topic":"Minum","vocab":[{"hanzi":"喝","pinyin":"he1","meaning":"minum"}]}}',
      );

      expect(material, isNotNull);
      expect(material!.topic, 'Minum');
      expect(material.vocab.single.hanzi, '喝');
    },
  );

  test('curriculum response parser tolerates missing material list', () {
    expect(parseCurriculumResponse({'materials': 'bad'}), isNull);
    expect(parseCurriculumResponse(null), isNull);
  });
}
