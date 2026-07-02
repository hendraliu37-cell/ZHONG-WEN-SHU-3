import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/services/idiom_bank.dart';
import 'package:zhongwen_shu/state/app_controller.dart'
    show buildGroundedHistory;

void main() {
  final fixture = <Map<String, dynamic>>[
    {
      's': '一帆风顺',
      't': '一帆風順',
      'py': 'yīfān fēngshùn',
      'zy': 'ㄧ ㄈㄢ ㄈㄥ ㄕㄨㄣˋ',
      'm': 'berjalan sangat lancar',
      'lit': 'satu layar angin mulus',
      'cat': 'chengyu',
      'exs': '祝你一帆风顺。',
      'exi': 'Semoga semuanya lancar.',
      'tone': 1,
    },
    {
      's': '入乡随俗',
      't': '入鄉隨俗',
      'py': 'rùxiāng suísú',
      'zy': 'ㄖㄨˋ ㄒㄧㄤ ㄙㄨㄟˊ ㄙㄨˊ',
      'm': 'di mana bumi dipijak di situ langit dijunjung',
      'lit': 'masuk desa ikut adat',
      'cat': 'suyu',
      'tone': 4,
    },
  ];

  test('load + lookup by 简 and 繁', () {
    final bank = IdiomBank.fromCards(fixture);
    expect(bank.lookup('一帆风顺')!.meaning, 'berjalan sangat lancar');
    expect(bank.lookup('一帆風順')!.category, 'chengyu');
    expect(bank.lookup('不存在'), isNull);
  });

  test('detect finds idioms inside a sentence (longest-match)', () {
    final bank = IdiomBank.fromCards(fixture);
    final hits = bank.detect('我希望这次旅行一帆风顺，谢谢。');
    expect(hits.map((e) => e.simplified), contains('一帆风顺'));
    expect(bank.detect('今天天气很好'), isEmpty);
  });

  test('parser tolerates loose idiom field values', () {
    final bank = IdiomBank.fromCards([
      {
        's': 123,
        't': null,
        'py': 456,
        'zy': null,
        'm': ' arti ',
        'lit': 789,
        'cat': 'unknown',
        'origin': null,
        'exs': ' \u4f8b\u53e5 ',
        'ext': null,
        'exi': 101,
        'tone': '4.0',
      },
    ]);

    final it = bank.lookup('123');
    expect(it, isNotNull);
    expect(it!.traditional, '123');
    expect(it.pinyin, '456');
    expect(it.meaning, 'arti');
    expect(it.literal, '789');
    expect(it.category, 'chengyu');
    expect(it.exampleS, '\u4f8b\u53e5');
    expect(it.exampleId, '101');
    expect(it.tone, 4);
  });

  test('randomForTeaching respects category filter', () {
    final bank = IdiomBank.fromCards(fixture);
    final it = bank.randomForTeaching(cat: 'suyu');
    expect(it, isNotNull);
    expect(it!.category, 'suyu');
    expect(it.simplified, '入乡随俗');
  });

  test('randomForTeaching returns null for empty pool', () {
    final bank = IdiomBank.fromCards(fixture);
    expect(bank.randomForTeaching(cat: 'yanyu'), isNull); // tak ada di fixture
    expect(IdiomBank.fromCards([]).randomForTeaching(), isNull);
  });

  test('contextBlock renders compact grounding string', () {
    final bank = IdiomBank.fromCards(fixture);
    final block = bank.contextBlock([bank.lookup('一帆风顺')!]);
    expect(block, contains('一帆风顺'));
    expect(block, contains('berjalan sangat lancar'));
    expect(block, contains('satu layar angin mulus'));
  });

  test('groundedHistory injects context only when idiom present', () {
    final bank = IdiomBank.fromCards(fixture);
    final base = [
      {'role': 'user', 'content': 'apa arti 一帆风顺?'},
    ];
    final grounded = buildGroundedHistory(base, bank);
    expect(grounded.last['content'], contains('一帆风顺'));
    expect(grounded.last['content'], contains('Bank idiom'));

    final base2 = [
      {'role': 'user', 'content': 'halo guru'},
    ];
    final same = buildGroundedHistory(base2, bank);
    expect(same.last['content'], 'halo guru'); // tak ada idiom → tak diubah
  });
}
