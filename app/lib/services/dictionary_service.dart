import 'dart:math' as math;

import '../models/vocab.dart';
import '../utils/cjk.dart';
import 'translation_service.dart';

/// Local dictionary lookup used to *enrich* a translation's word breakdown.
/// Indexed by both 简 and 繁 headwords over whatever vocab is currently loaded
/// (seed + downloaded packs + user cards). The dictionary is still being built,
/// so this is sparse for now — entries it doesn't know fall back to the LLM's
/// own breakdown. The boundary stays clean: feed it [load], ask it [enrich].
class DictionaryService {
  final Map<String, VocabEntry> _byHanzi = {};

  void load(Iterable<VocabEntry> entries) {
    _byHanzi.clear();
    for (final e in entries) {
      if (e.simplified.isNotEmpty) _byHanzi[e.simplified] = e;
      if (e.traditional.isNotEmpty) _byHanzi[e.traditional] = e;
    }
  }

  VocabEntry? lookup(String hanzi) => _byHanzi[hanzi.trim()];

  /// Returns the token with dictionary data layered over the LLM's, when the
  /// headword is known locally. Local pinyin/meaning/level win (authoritative).
  TranslateToken enrich(TranslateToken t) {
    final hit = lookup(t.hanzi);
    if (hit == null) return t;
    return t.copyWith(
      pinyin: hit.pinyin.isNotEmpty ? hit.pinyin : t.pinyin,
      meaning: hit.primaryMeaning.isNotEmpty ? hit.primaryMeaning : t.meaning,
      altMeanings: hit.alternativeMeanings.isNotEmpty
          ? hit.alternativeMeanings
          : t.altMeanings,
      hsk: hit.hskLevel ?? t.hsk,
    );
  }

  List<TranslateToken> enrichAll(List<TranslateToken> tokens) =>
      tokens.map(enrich).toList();

  static const int _maxWord = 6;

  /// Segments Chinese [text] into word tokens via greedy longest-match against
  /// known headwords (so the breakdown needs no LLM round-trip). Known words
  /// carry pinyin/meaning/HSK; unknown spans fall back to single characters
  /// (hanzi only). Non-CJK runs (punctuation, latin, spaces) are skipped.
  List<TranslateToken> segment(String text) {
    final out = <TranslateToken>[];
    var i = 0;
    while (i < text.length) {
      final ch = text[i];
      if (!kCjkChar.hasMatch(ch)) {
        i++;
        continue;
      }
      // Try the longest known headword starting here.
      VocabEntry? hit;
      var len = 0;
      final maxLen = math.min(_maxWord, text.length - i);
      for (var l = maxLen; l >= 1; l--) {
        final cand = text.substring(i, i + l);
        final e = _byHanzi[cand];
        if (e != null) {
          hit = e;
          len = l;
          break;
        }
      }
      if (hit != null) {
        out.add(
          TranslateToken(
            hanzi: text.substring(i, i + len),
            pinyin: hit.pinyin,
            meaning: hit.primaryMeaning,
            altMeanings: hit.alternativeMeanings,
            hsk: hit.hskLevel,
          ),
        );
        i += len;
      } else {
        out.add(TranslateToken(hanzi: ch));
        i++;
      }
    }
    return out;
  }
}
