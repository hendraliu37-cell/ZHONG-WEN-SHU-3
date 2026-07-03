import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import '../models/idiom.dart';
import '../utils/cjk.dart';

/// Bank idiom & peribahasa. Sumber tunggal yang sama dipakai sebagai paket
/// flashcard (lewat manifest) DAN pengetahuan Guru (grounding + mengajar).
/// Batas bersih: [load] sekali, lalu [lookup]/[detect]/[contextBlock].
class IdiomBank {
  final Map<String, Idiom> _byHanzi = {};
  final List<Idiom> _all = [];
  bool _loaded = false;
  final math.Random _rng = math.Random();

  IdiomBank();

  /// Konstruksi langsung dari list map (dipakai test & internal).
  factory IdiomBank.fromCards(List<Map<String, dynamic>> cards) {
    final b = IdiomBank();
    b._ingest(cards.map(Idiom.fromJson));
    b._loaded = true;
    return b;
  }

  void _ingest(Iterable<Idiom> items) {
    for (final it in items) {
      _all.add(it);
      if (it.simplified.isNotEmpty) _byHanzi[it.simplified] = it;
      if (it.traditional.isNotEmpty) _byHanzi[it.traditional] = it;
    }
  }

  /// Muat aset sekali (idempotent, aman bila aset tak ada).
  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/packs/idioms.json');
      _ingest(_parseIdiomPayload(raw));
    } catch (_) {
      // aset belum ada / gagal → bank kosong, fitur lain tetap jalan.
    }
    _loaded = true;
  }

  Idiom? lookup(String hanzi) => _byHanzi[hanzi.trim()];

  int get count => _all.length;

  static const int _maxLen =
      8; // peribahasa terpanjang di bank ~8 hanzi (mis. 一分耕耘一分收获)

  /// Idiom yang muncul dalam [text] (longest-match, tanpa tumpang tindih).
  List<Idiom> detect(String text) {
    final out = <Idiom>[];
    var i = 0;
    while (i < text.length) {
      if (!kCjkChar.hasMatch(text[i])) {
        i++;
        continue;
      }
      Idiom? hit;
      var len = 0;
      final maxLen = math.min(_maxLen, text.length - i);
      for (var l = maxLen; l >= 2; l--) {
        final cand = text.substring(i, i + l);
        final e = _byHanzi[cand];
        if (e != null) {
          hit = e;
          len = l;
          break;
        }
      }
      if (hit != null) {
        out.add(hit);
        i += len;
      } else {
        i++;
      }
    }
    return out;
  }

  /// Pilih satu idiom untuk diajarkan (opsional per kategori).
  Idiom? randomForTeaching({String? cat}) {
    final pool = cat == null
        ? _all
        : _all.where((e) => e.category == cat).toList();
    if (pool.isEmpty) return null;
    return pool[_rng.nextInt(pool.length)];
  }

  /// Blok ringkas untuk disuntik ke prompt LLM.
  String contextBlock(List<Idiom> items) {
    final label = {'chengyu': '成语', 'yanyu': '谚语', 'suyu': '俗语'};
    return items
        .map((e) {
          final parts = <String>[
            '${label[e.category] ?? ''} ${e.simplified} (${e.pinyin})',
          ];
          if (e.literal.isNotEmpty) parts.add('harfiah: "${e.literal}"');
          parts.add('makna: ${e.meaning}');
          if (e.exampleS.isNotEmpty) parts.add('contoh: ${e.exampleS}');
          if (e.origin.isNotEmpty) parts.add('asal: ${e.origin}');
          return parts.join('; ');
        })
        .join('\n');
  }
}

Iterable<Idiom> _parseIdiomPayload(Object? payload) {
  final decoded = _jsonValue(payload);
  final cards = _jsonValue(
    decoded is Map ? (decoded['cards'] ?? decoded['data']) : decoded,
  );
  final list = cards is List ? cards : const [];
  return list.whereType<Map>().map(
    (e) => Idiom.fromJson(Map<String, dynamic>.from(e)),
  );
}

Object? _jsonValue(Object? payload) {
  if (payload is String) {
    final text = payload.trim();
    if (!text.startsWith('{') && !text.startsWith('[')) return payload;
    try {
      return jsonDecode(text);
    } catch (_) {
      return payload;
    }
  }
  return payload;
}

@visibleForTesting
List<Idiom> parseIdiomPayloadForTest(Object? payload) =>
    _parseIdiomPayload(payload).toList();
