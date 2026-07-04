import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhongwen_shu/models/curriculum.dart';
import 'package:zhongwen_shu/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          recordChannel,
          (MethodCall call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  test(
    'restore skips malformed card and srs keys without dropping valid data',
    () {
      final c = AppController();

      c.restoreForTest({
        'cards': {
          '1': {'s': '吃', 't': '吃', 'py': 'chī', 'm': 'makan'},
          'bad-key': {'s': '坏', 't': '壞', 'py': 'huài', 'm': 'rusak'},
        },
        'srs': {
          'bad-srs': {'reps': 99},
        },
        'decks': [
          'not-a-deck',
          {
            'id': 'custom',
            'idx': '01',
            'name': 'Custom',
            'isPack': 'true',
            'cardIds': ['1', 2.0, 'bad-id'],
          },
          {
            'id': 'cloud',
            'idx': '02',
            'name': 'Cloud',
            'card_ids': '["1",2,"bad-id"]',
          },
          {
            'id': '',
            'idx': '99',
            'name': 'Broken',
            'cardIds': [1],
          },
        ],
      });

      expect(c.cards.keys, [1]);
      expect(c.cards[1]!.simplified, '吃');
      expect(c.srs.containsKey(1), isTrue);
      expect(c.srs.length, 1);
      expect(c.decks.map((d) => d.id), ['custom', 'cloud']);
      expect(c.decks.first.cardIds, [1]);
      expect(c.decks.first.isPack, isTrue);
      expect(c.decks.last.cardIds, [1]);
    },
  );

  test('restore replaces stale card state and repairs next id', () {
    final c = AppController();

    c.restoreForTest({
      'cards': {
        '1': {'s': '旧', 't': '舊', 'py': 'jiu4', 'm': 'lama'},
      },
      'decks': [
        {
          'id': 'old',
          'idx': '00',
          'name': 'Old',
          'cardIds': [1],
        },
      ],
      'installedPacks': ['hsk1', 12, '', null],
      'nextId': 2,
    });

    c.restoreForTest({
      'cards': {
        '5': {'s': '新', 't': '新', 'py': 'xin1', 'm': 'baru'},
      },
      'decks': [
        {
          'id': 'fresh',
          'idx': '01',
          'name': 'Fresh',
          'cardIds': [5],
        },
      ],
      'installedPacks': ['tocfl_a1', 99],
      'nextId': 0,
    });
    c
      ..writeDeck = 0
      ..saveWrite('学', 'xue2', 'belajar');

    expect(c.cards.keys.toList()..sort(), [5, 6]);
    expect(c.cards.containsKey(1), isFalse);
    expect(c.srs.keys.toList()..sort(), [5, 6]);
    expect(c.decks.single.cardIds, [5, 6]);
    expect(c.installedPacks, {'tocfl_a1'});
  });

  test('restore tolerates legacy string card ids in test history', () {
    final c = AppController();

    c.restoreForTest({
      'cards': {
        '1': {'s': '吃', 't': '吃', 'py': 'chi1', 'm': 'makan'},
        '2': {'s': '喝', 't': '喝', 'py': 'he1', 'm': 'minum'},
      },
      'testHistory': [
        {
          'id': 'legacy',
          'mode': 'mc',
          'title': 'Tes lama',
          'direction': 'zh2id',
          'cardIds': ['1', 2.0, 99, 'bad-id'],
          'index': '1',
          'score': '1',
          'startedAt': '2026-07-01T00:00:00.000',
          'updatedAt': '2026-07-01T00:01:00.000',
        },
      ],
    });

    expect(c.testHistory, hasLength(1));
    expect(c.testHistory.single.cardIds, [1, 2]);
    expect(c.testHistory.single.index, 1);
    expect(c.testHistory.single.score, 1);
  });

  test('restore prunes stale test history card ids and stale resumes', () {
    final c = AppController();

    c.restoreForTest({
      'cards': {
        '1': {'s': '\u5403', 't': '\u5403', 'py': 'chi1', 'm': 'makan'},
      },
      'testHistory': [
        {
          'id': 'gone',
          'mode': 'mc',
          'title': 'Semua kartu hilang',
          'direction': 'zh2id',
          'cardIds': [99],
          'index': 0,
          'score': 0,
          'startedAt': '2026-07-01T00:00:00.000',
          'updatedAt': '2026-07-01T00:01:00.000',
        },
        {
          'id': 'stale',
          'mode': 'mc',
          'title': 'Sebagian kartu hilang',
          'direction': 'zh2id',
          'cardIds': [1, 99],
          'index': 2,
          'score': 5,
          'completed': false,
          'startedAt': '2026-07-01T00:00:00.000',
          'updatedAt': '2026-07-01T00:02:00.000',
        },
      ],
    });

    expect(c.testHistory, hasLength(1));
    expect(c.testHistory.single.id, 'stale');
    expect(c.testHistory.single.cardIds, [1]);
    expect(c.testHistory.single.index, 1);
    expect(c.testHistory.single.score, 1);
    expect(c.testHistory.single.completed, isTrue);
  });

  test('restore orders test history by latest update first', () {
    final c = AppController();

    c.restoreForTest({
      'cards': {
        '1': {'s': '\u5403', 't': '\u5403', 'py': 'chi1', 'm': 'makan'},
      },
      'testHistory': [
        {
          'id': 'older',
          'mode': 'mc',
          'title': 'Lebih lama',
          'direction': 'zh2id',
          'cardIds': [1],
          'index': 0,
          'score': 0,
          'startedAt': '2026-07-01T00:00:00.000',
          'updatedAt': '2026-07-01T00:10:00.000',
        },
        {
          'id': 'newer',
          'mode': 'mc',
          'title': 'Lebih baru',
          'direction': 'zh2id',
          'cardIds': [1],
          'index': 0,
          'score': 0,
          'startedAt': '2026-07-01T00:05:00.000',
          'updatedAt': '2026-07-01T00:20:00.000',
        },
      ],
    });

    expect(c.testHistory.map((h) => h.id), ['newer', 'older']);
  });

  test('restore respects daily material snooze windows', () {
    final empty = AppController();
    empty.restoreForTest({
      'dailyMaterialHiddenUntil': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    });

    expect(empty.showDailyMaterialBanner, isFalse);

    final hidden = AppController();
    hidden.dailyMaterial = _dailyMaterial();
    hidden.restoreForTest({
      'dailyMaterialHiddenUntil': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    });

    expect(hidden.showDailyMaterialBanner, isFalse);

    final visible = AppController();
    visible.dailyMaterial = _dailyMaterial();
    visible.restoreForTest({
      'dailyMaterialHiddenUntil': DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toIso8601String(),
    });

    expect(visible.showDailyMaterialBanner, isTrue);
  });

  test('restore keeps newest local chat history when payload is oversized', () {
    final c = AppController();

    c.restoreForTest({
      'chatHistory': [
        for (var i = 0; i < 125; i++)
          {'who': i.isEven ? 'me' : 't', 'text': 'pesan $i'},
      ],
    });

    expect(c.messages, hasLength(120));
    expect(c.messages.first.text, 'pesan 5');
    expect(c.messages.last.text, 'pesan 124');
  });

  test('restore skips malformed history rows without dropping valid rows', () {
    final c = AppController();

    c.restoreForTest({
      'cards': {
        '1': {'s': '吃', 't': '吃', 'py': 'chi1', 'm': 'makan'},
      },
      'chatHistory': [
        {'who': 'me', 'text': 'valid chat'},
        {'who': 1, 'text': 99},
      ],
      'translateHistory': [
        {
          'source': '吃',
          'translation': 'makan',
          'from': 'zh',
          'to': 'id',
          'at': '2026-07-01T00:00:00.000',
        },
        {'source': 7, 'translation': 'loose', 'from': 9, 'to': 'bad', 'at': 99},
      ],
      'testHistory': [
        {
          'id': 'ok',
          'mode': 'mc',
          'title': 'Tes valid',
          'direction': 'zh2id',
          'cardIds': [1],
          'index': 0,
          'score': 0,
          'startedAt': '2026-07-01T00:00:00.000',
          'updatedAt': '2026-07-01T00:01:00.000',
        },
        {
          'id': 9,
          'title': 99,
          'cardIds': [1],
          'completed': 1,
          'flipped': 'yes',
          'picked': 7,
        },
      ],
    });

    expect(c.messages.map((m) => m.text), ['valid chat', '99']);
    expect(c.messages.last.who, 't');
    expect(c.trHistory.map((h) => h.source), ['吃', '7']);
    expect(c.trHistory.map((h) => h.translation), ['makan', 'loose']);
    expect(c.trHistory.last.from, 'zh');
    expect(c.trHistory.last.to, 'id');
    expect(c.testHistory.map((h) => h.id), ['ok', '9']);
    expect(c.testHistory.last.title, '99');
    expect(c.testHistory.last.completed, isTrue);
    expect(c.testHistory.last.flipped, isTrue);
    expect(c.testHistory.last.picked, '7');
  });

  test('restore accepts cloud-shaped test history payloads', () {
    final c = AppController();

    c.restoreForTest({
      'cards': {
        '1': {'s': '吃', 't': '吃', 'py': 'chi1', 'm': 'makan'},
        '2': {'s': '喝', 't': '喝', 'py': 'he1', 'm': 'minum'},
      },
      'testHistory': [
        {
          'id': 'cloud',
          'mode': 'mc',
          'title': 'Tes cloud',
          'deck_id': 'deck-a',
          'direction': 'zh2id',
          'card_ids': '["1",2,99]',
          'index': '1',
          'score': '1',
          'startedAt': '2026-07-03T00:00:00.000',
          'updatedAt': '2026-07-03T00:01:00.000',
        },
      ],
    });

    expect(c.testHistory, hasLength(1));
    expect(c.testHistory.single.deckId, 'deck-a');
    expect(c.testHistory.single.cardIds, [1, 2]);
    expect(c.testHistory.single.index, 1);
    expect(c.testHistory.single.score, 1);
  });

  test('restore accepts numeric timestamps in local history', () {
    final c = AppController();
    final epochMs = DateTime.utc(2026, 7, 1, 10).millisecondsSinceEpoch;
    final epochSeconds =
        DateTime.utc(2026, 7, 1, 11).millisecondsSinceEpoch ~/ 1000;

    c.restoreForTest({
      'cards': {
        '1': {'s': '\u5403', 't': '\u5403', 'py': 'chi1', 'm': 'makan'},
      },
      'translateHistory': [
        {
          'source': '\u5403',
          'translation': 'makan',
          'from': 'zh',
          'to': 'id',
          'at': epochMs,
        },
      ],
      'testHistory': [
        {
          'id': 'numeric-time',
          'mode': 'mc',
          'title': 'Tes timestamp',
          'direction': 'zh2id',
          'cardIds': [1],
          'startedAt': epochSeconds,
          'updatedAt': '$epochMs',
        },
      ],
    });

    expect(
      c.trHistory.single.at,
      DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal(),
    );
    expect(
      c.testHistory.single.startedAt,
      DateTime.fromMillisecondsSinceEpoch(
        epochSeconds * 1000,
        isUtc: true,
      ).toLocal(),
    );
    expect(
      c.testHistory.single.updatedAt,
      DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal(),
    );
  });

  test('restore orders translate history by latest timestamp first', () {
    final c = AppController();

    c.restoreForTest({
      'translateHistory': [
        {
          'source': 'lama',
          'translation': '\u65e7',
          'from': 'id',
          'to': 'zh',
          'at': '2026-07-01T00:00:00.000',
        },
        {
          'source': 'baru',
          'translation': '\u65b0',
          'from': 'id',
          'to': 'zh',
          'at': '2026-07-01T00:05:00.000',
        },
        {
          'source': 'tanpa waktu',
          'translation': '\u8bb0\u5f55',
          'from': 'id',
          'to': 'zh',
        },
      ],
    });

    expect(c.trHistory.map((h) => h.source), ['baru', 'lama', 'tanpa waktu']);
  });

  test('restore normalizes translate history engine values', () {
    final c = AppController();

    c.restoreForTest({
      'translateHistory': [
        {
          'source': 'halo',
          'translation': '\u4f60\u597d',
          'from': 'id',
          'to': 'zh',
          'engine': 'AI',
          'at': '2026-07-01T00:00:00.000',
        },
        {
          'source': 'makan',
          'translation': '\u5403',
          'from': 'id',
          'to': 'zh',
          'engine': 'legacy-online',
          'at': '2026-07-01T00:01:00.000',
        },
      ],
    });

    expect(c.trHistory.map((h) => h.engine), ['dict', 'ai']);

    c.trUseHistory(c.trHistory.first);
    expect(c.trEngine, 'dict');
  });

  test('restore accepts legacy string ids for AI-focused learning cards', () {
    final c = AppController();

    c.restoreForTest({
      'cards': {
        '1': {'s': '吃', 't': '吃', 'py': 'chi1', 'm': 'makan'},
        '2': {'s': '喝', 't': '喝', 'py': 'he1', 'm': 'minum'},
      },
      'aiFocusCardIds': ['2', 1, 'bad-id', 99],
    });

    expect(c.aiFocusCardIds, [2, 1]);
    expect(c.smartPracticeBase(limit: 2), [2, 1]);
  });

  test('restore normalizes invalid preference values', () {
    final c = AppController();

    c.restoreForTest({
      'themeMode': 'neon',
      'track': 'trad',
      'primary': 'classic',
    });

    expect(c.themeMode, 'system');
    expect(c.track, 'both');
    expect(c.primary, 'simplified');
  });

  test('restore keeps primary aligned when track is not both', () {
    final simplified = AppController();
    simplified.restoreForTest({
      'track': 'simplified',
      'primary': 'traditional',
    });

    expect(simplified.track, 'simplified');
    expect(simplified.primary, 'simplified');
    expect(simplified.usesTraditionalHanzi, isFalse);

    final traditional = AppController();
    traditional.restoreForTest({
      'track': 'traditional',
      'primary': 'simplified',
    });

    expect(traditional.track, 'traditional');
    expect(traditional.primary, 'traditional');
    expect(traditional.usesTraditionalHanzi, isTrue);
  });

  test('restore tolerates malformed scalar and collection containers', () {
    final c = AppController();

    expect(
      () => c.restoreForTest({
        'onboarded': 'true',
        'zhuyin': 'false',
        'xp': '42',
        'streak': 2.9,
        'lastTestPct': 150,
        'lastUjianAkhirPct': -7,
        'lastActiveDate': 123,
        'dailyMaterialHiddenUntil': 99,
        'nextId': 'bad',
        'installedPacks': 'hsk1',
        'cards': {
          '3': {'s': '\u559d', 't': '\u559d', 'py': 'he1', 'm': 'minum'},
        },
        'srs': 'broken',
        'decks': 'broken',
        'chatHistory': 'broken',
        'translateHistory': {'not': 'a-list'},
        'testHistory': 'broken',
        'aiFocusCardIds': 'broken',
      }),
      returnsNormally,
    );

    expect(c.onboarded, isTrue);
    expect(c.zhuyin, isFalse);
    expect(c.xp, 42);
    expect(c.streak, 2);
    expect(c.lastTestPct, 100);
    expect(c.lastUjianAkhirPct, 0);
    expect(c.lastActiveDate, isNull);
    expect(c.dailyMaterialHiddenUntil, isNull);
    expect(c.installedPacks, isEmpty);
    expect(c.cards.keys, [3]);
    expect(c.srs.keys, [3]);
    expect(c.decks, isEmpty);
    expect(c.messages, isEmpty);
    expect(c.trHistory, isEmpty);
    expect(c.testHistory, isEmpty);
    expect(c.aiFocusCardIds, isEmpty);
  });

  test('restore tolerates malformed SRS rows without dropping cards', () {
    final c = AppController();

    expect(
      () => c.restoreForTest({
        'cards': {
          '1': {'s': '\u5403', 't': '\u5403', 'py': 'chi1', 'm': 'makan'},
          '2': {'s': '\u559d', 't': '\u559d', 'py': 'he1', 'm': 'minum'},
        },
        'srs': {
          '1': {
            's': '9.5',
            'd': '2.25',
            'due': 'bad-date',
            'last': 99,
            'reps': '4',
            'lapses': -3,
            'new': 'false',
          },
          '2': {
            's': null,
            'd': null,
            'due': null,
            'reps': null,
            'lapses': null,
            'new': 'true',
          },
        },
      }),
      returnsNormally,
    );

    expect(c.cards.keys.toList()..sort(), [1, 2]);
    expect(c.srs[1]!.stability, 9.5);
    expect(c.srs[1]!.difficulty, 2.25);
    expect(c.srs[1]!.reps, 4);
    expect(c.srs[1]!.lapses, 0);
    expect(c.srs[1]!.isNew, isFalse);
    expect(c.srs[2]!.stability, 0);
    expect(c.srs[2]!.difficulty, 0);
    expect(c.srs[2]!.reps, 0);
    expect(c.srs[2]!.isNew, isTrue);
  });

  test('logout persists guest profile reset locally', () async {
    final c = AppController()
      ..onboarded = true
      ..profileName = 'Hendra'
      ..profileHandle = 'hendra'
      ..profileId = '#1234'
      ..avatarUrl = 'https://example.com/avatar.png'
      ..xp = 900
      ..streak = 7
      ..lastTestPct = 88
      ..lastUjianAkhirPct = 91
      ..lastActiveDate = '2026-07-04';

    await c.logout();

    expect(c.onboarded, isFalse);
    expect(c.profileName, 'Murid');
    expect(c.profileHandle, isEmpty);
    expect(c.profileId, isEmpty);
    expect(c.avatarUrl, isNull);
    expect(c.xp, 0);
    expect(c.streak, 0);
    expect(c.lastTestPct, 0);
    expect(c.lastUjianAkhirPct, 0);
    expect(c.lastActiveDate, isNull);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('zws_state_v1');
    expect(raw, isNotNull);
    final saved = Map<String, dynamic>.from(jsonDecode(raw!) as Map);
    expect(saved['onboarded'], isFalse);
    expect(saved['xp'], 0);
    expect(saved['streak'], 0);
    expect(saved['lastTestPct'], 0);
    expect(saved['lastUjianAkhirPct'], 0);
    expect(saved['lastActiveDate'], isNull);
  });
}

DailyMaterial _dailyMaterial() => const DailyMaterial(
  topic: 'Latihan sapaan',
  vocab: [VocabItem(hanzi: '你好', pinyin: 'nǐ hǎo', meaning: 'halo')],
  sentences: ['你好，老师！'],
  exercise: 'Buat satu kalimat sapaan.',
);
