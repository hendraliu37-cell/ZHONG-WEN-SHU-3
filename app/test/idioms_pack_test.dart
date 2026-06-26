import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('idioms.json valid, lengkap, field wajib & kategori benar', () {
    final raw = File('assets/packs/idioms.json').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    expect(data['standard'], 'idiom');
    final cards = (data['cards'] as List).cast<Map<String, dynamic>>();
    expect(cards.length, greaterThanOrEqualTo(820));
    const cats = {'chengyu', 'yanyu', 'suyu'};
    for (final c in cards) {
      for (final k in ['s', 't', 'py', 'zy', 'm', 'cat', 'tone']) {
        expect((c[k]?.toString() ?? '').isNotEmpty, isTrue,
            reason: '$k kosong di ${c['s']}');
      }
      expect(cats.contains(c['cat']), isTrue, reason: 'cat tak valid di ${c['s']}');
    }
    final hanzi = cards.map((c) => c['s']).toSet();
    expect(hanzi.contains('公共汽车'), isFalse);
    expect(hanzi.contains('高速公路'), isFalse);
  });

  test('paket idioms terdaftar di manifest', () {
    final raw = File('assets/packs/manifest.json').readAsStringSync();
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    final pack = list.firstWhere((p) => p['id'] == 'idioms');
    expect(pack['standard'], 'idiom');
    expect(pack['asset'], 'assets/packs/idioms.json');
  });
}
