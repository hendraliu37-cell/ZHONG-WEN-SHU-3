import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUp(() {
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
          'cardIds': ['1', 2.0, 'bad-id'],
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
}
