import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
          {
            'id': 'custom',
            'idx': '01',
            'name': 'Custom',
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
}
