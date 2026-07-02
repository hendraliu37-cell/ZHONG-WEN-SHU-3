import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
            'cardIds': ['1', 2.0, 'bad-id'],
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
      expect(c.decks.single.cardIds, [1]);
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
        '1': {'s': 'åƒ', 't': 'åƒ', 'py': 'chi1', 'm': 'makan'},
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

  test('restore respects daily material snooze windows', () {
    final hidden = AppController();
    hidden.restoreForTest({
      'dailyMaterialHiddenUntil': DateTime.now()
          .add(const Duration(hours: 1))
          .toIso8601String(),
    });

    expect(hidden.showDailyMaterialBanner, isFalse);

    final visible = AppController();
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
}
