import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/state/app_controller.dart';

void main() {
  test('pack manifest parser skips malformed rows and keeps valid packs', () {
    final packs = parsePackManifest([
      'bad-row',
      {'id': '', 'name': 'No id', 'asset': 'assets/packs/no-id.json'},
      {'id': 'no_asset', 'name': 'No asset'},
      {
        'id': 123,
        'name': null,
        'meta': 456,
        'standard': null,
        'levelTag': 789,
        'asset': ' assets/packs/hsk1.json ',
      },
    ]);

    expect(packs, hasLength(1));
    expect(packs.single.id, '123');
    expect(packs.single.name, '123');
    expect(packs.single.meta, '456');
    expect(packs.single.standard, 'mixed');
    expect(packs.single.levelTag, '789');
    expect(packs.single.asset, 'assets/packs/hsk1.json');
  });

  test('pack manifest parser tolerates non-list payloads', () {
    expect(parsePackManifest({'id': 'hsk1'}), isEmpty);
    expect(parsePackManifest(null), isEmpty);
  });
}
