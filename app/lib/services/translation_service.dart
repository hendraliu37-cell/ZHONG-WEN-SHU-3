import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/vocab.dart';
import 'llm_service.dart';

/// One token of a translation's word-by-word breakdown.
class TranslateToken {
  final String hanzi;
  final String pinyin;
  final String meaning;
  final int? hsk;

  /// Additional meanings (Pleco-style). First meaning is in [meaning].
  final List<String> altMeanings;
  const TranslateToken({
    required this.hanzi,
    this.pinyin = '',
    this.meaning = '',
    this.hsk,
    this.altMeanings = const [],
  });

  /// All meanings (primary + alternatives).
  List<String> get allMeanings => [
    if (meaning.isNotEmpty) meaning,
    ...altMeanings,
  ];

  factory TranslateToken.fromJson(Map j) {
    final m = _stringish(j['meaning'] ?? j['m']);
    final split = VocabEntry.splitMeanings(m);
    final alts = _stringListish(j['altMeanings'] ?? j['alts']);
    return TranslateToken(
      hanzi: _stringish(j['hanzi'] ?? j['h'] ?? j['z']),
      pinyin: _stringish(j['pinyin'] ?? j['py']),
      meaning: split.isEmpty ? m : split.first,
      hsk: _intish(j['hsk']),
      altMeanings: [
        if (split.length > 1) ...split.sublist(1),
        ...alts.map((e) => e.toString()),
      ],
    );
  }

  TranslateToken copyWith({
    String? pinyin,
    String? meaning,
    int? hsk,
    List<String>? altMeanings,
  }) => TranslateToken(
    hanzi: hanzi,
    pinyin: pinyin ?? this.pinyin,
    meaning: meaning ?? this.meaning,
    hsk: hsk ?? this.hsk,
    altMeanings: altMeanings ?? this.altMeanings,
  );
}

String _stringish(Object? value) => value?.toString().trim() ?? '';

List<String> _stringListish(Object? value) {
  if (value is List) {
    return value.map(_stringish).where((text) => text.isNotEmpty).toList();
  }
  final text = _stringish(value);
  if (text.isEmpty) return const [];
  return VocabEntry.splitMeanings(text);
}

int? _intish(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return int.tryParse(text) ?? double.tryParse(text)?.toInt();
}

class TranslationResult {
  final String translation;
  final String? pinyin;
  final List<TranslateToken> alternatives;
  final List<TranslateToken> tokens;
  const TranslationResult({
    required this.translation,
    this.pinyin,
    this.alternatives = const [],
    this.tokens = const [],
  });
}

/// Translator: LLM-first (accurate, natural), dictionary fallback (offline, fast).
/// The LLM handles full-sentence context and word choice; the dictionary enriches
/// the per-word breakdown with pinyin/HSK level when available.
class TranslationService {
  TranslationService({LlmService? llm}) : _llm = llm ?? LlmService();

  final LlmService _llm;
  final Map<String, _DictEntry> _dict = {};
  bool _loaded = false;

  static const _fallbackSimpToTrad = {
    '这': '這',
    '个': '個',
    '们': '們',
    '为': '為',
    '来': '來',
    '说': '說',
    '对': '對',
    '会': '會',
    '学': '學',
    '习': '習',
    '书': '書',
    '语': '語',
    '问': '問',
    '听': '聽',
    '读': '讀',
    '写': '寫',
    '话': '話',
    '请': '請',
    '谢': '謝',
    '欢': '歡',
    '觉': '覺',
    '饭': '飯',
    '饮': '飲',
    '电': '電',
    '脑': '腦',
    '机': '機',
    '后': '後',
    '里': '裡',
    '过': '過',
    '还': '還',
    '没': '沒',
    '气': '氣',
    '国': '國',
    '爱': '愛',
    '长': '長',
    '吗': '嗎',
    '点': '點',
    '买': '買',
    '卖': '賣',
    '开': '開',
    '关': '關',
  };

  SupabaseClient? get _sb {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Load the full combined dictionary (13K+ entries) from assets.
  void loadFromCards(Iterable<Map<String, dynamic>> cards) {
    for (final c in cards) {
      final s = _stringish(c['s']);
      if (s.isEmpty) continue;
      final rawT = _stringish(c['t']);
      final t = VocabEntry.normalizeModernTraditional(rawT.isEmpty ? s : rawT);
      final entry = _DictEntry(
        simplified: s,
        traditional: t,
        pinyin: _stringish(c['py']),
        meaning: _stringish(c['m']),
        hsk: _intish(c['hsk']),
      );
      _dict[s] = entry;
      if (t != s) _dict[t] = entry;
    }
    _loaded = true;
  }

  /// Load dictionary.json from rootBundle (called at startup).
  Future<void> loadAsset() async {
    try {
      final raw = await rootBundle.loadString('assets/packs/dictionary.json');
      final list = jsonDecode(raw) as List;
      loadFromCards(
        list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[dict] dictionary.json load failed: $e');
    }
  }

  bool get isLoaded => _loaded;

  /// Enrich a token with dictionary data (pinyin/HSK/all meanings) when the headword is known.
  TranslateToken _enrich(TranslateToken t) {
    final hit = _dict[t.hanzi.trim()];
    if (hit == null) return t;
    final allMeanings = VocabEntry.splitMeanings(hit.meaning);
    return t.copyWith(
      pinyin: hit.pinyin.isNotEmpty ? hit.pinyin : t.pinyin,
      hsk: hit.hsk ?? t.hsk,
      meaning: allMeanings.isNotEmpty ? allMeanings.first : t.meaning,
      altMeanings: allMeanings.length > 1
          ? allMeanings.sublist(1)
          : t.altMeanings,
    );
  }

  String? lastError;

  /// Translate [text] from [from] to [to]. LLM-first, dictionary fallback.
  /// [engine]: 'ai' = LLM (akurat, butuh online), 'dict' = kamus (cepat, offline).
  Future<TranslationResult?> translate(
    String text, {
    required String from,
    required String to,
    String track = 'simplified',
    String engine = 'ai',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (from == to) return null;
    lastError = null;

    // 1. Try LLM unless user explicitly chose dictionary
    if (engine != 'dict') {
      final llmResult = await _translateViaLLM(trimmed, from, to, track);
      if (llmResult != null) return llmResult;
    }

    // 2. Fallback: dictionary-based (offline)
    if (from == 'zh' && to == 'id') {
      final result = _dictTranslateZhToId(trimmed, track);
      if (result.translation.trim().isEmpty && result.tokens.isEmpty) {
        lastError = 'Tidak ada Hanzi yang bisa diterjemahkan.';
        return null;
      }
      return result;
    } else if (from == 'id' && to == 'zh') {
      return _dictTranslateIdToZh(trimmed, track);
    }
    return null;
  }

  Future<TranslationResult?> _translateViaLLM(
    String text,
    String from,
    String to,
    String track,
  ) async {
    final sb = _sb;
    if (sb == null) {
      lastError = 'Supabase belum siap - mode offline';
      return _translateViaDirectLlm(text, from, to, track);
    }
    try {
      final res = await sb.functions
          .invoke(
            'translate',
            body: {'text': text, 'from': from, 'to': to, 'track': track},
          )
          .timeout(const Duration(seconds: 40));

      // res.data bisa Map (auto-parsed) atau String (raw JSON) tergantung SDK version
      dynamic data = res.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      if (data is Map) {
        // Error response dari edge function
        if (data['error'] is String) {
          lastError = 'Server: ${data['error']}';
        } else if (data['translation'] is String) {
          final trans = (data['translation'] as String).trim();
          if (trans.isNotEmpty) {
            final tokens = _tokensFromJson(data['tokens']);
            final enriched = tokens.map(_enrich).toList();
            return TranslationResult(
              translation: trans,
              pinyin: (data['pinyin'] as String?)?.trim().isNotEmpty == true
                  ? data['pinyin'] as String
                  : null,
              tokens: enriched,
            );
          }
        }
      }
      lastError = 'Format respons tidak valid';
    } catch (e) {
      lastError =
          'Koneksi gagal: ${e.toString().substring(0, math.min(80, e.toString().length))}';
    }
    return _translateViaDirectLlm(text, from, to, track);
  }

  Future<TranslationResult?> _translateViaDirectLlm(
    String text,
    String from,
    String to,
    String track,
  ) async {
    final fromLabel = from == 'zh' ? 'Mandarin' : 'Indonesia';
    final toLabel = to == 'zh' ? 'Mandarin' : 'Indonesia';
    final variant = track == 'traditional'
        ? 'Gunakan hanzi tradisional untuk semua output Mandarin.'
        : 'Gunakan hanzi sederhana untuk semua output Mandarin.';
    final system =
        'Kamu mesin terjemahan Mandarin-Indonesia. Terjemahkan natural dan akurat. '
        '$variant Balas hanya JSON valid tanpa markdown.';
    final prompt =
        'Terjemahkan teks dari $fromLabel ke $toLabel.\n'
        'Teks: $text\n\n'
        'Balas tepat dengan objek JSON: '
        '{"translation":"...","pinyin":"...","tokens":[{"hanzi":"...","pinyin":"...","meaning":"...","hsk":1}]} '
        'Kosongkan pinyin jika bukan output Mandarin. tokens boleh kosong kalau tidak relevan.';

    final reply = await _llm.chat(
      [
        {'role': 'user', 'content': prompt},
      ],
      track: track,
      level: 'translation',
      systemOverride: system,
      temperature: 0.2,
      maxTokens: 700,
    );
    if (reply == null || reply.trim().isEmpty) {
      if (_llm.lastError != null) lastError = 'Direct LLM: ${_llm.lastError}';
      return null;
    }
    final data = _decodeJsonObject(reply);
    final parsed = data == null ? null : _parseLlmTranslation(data);
    if (parsed != null) {
      lastError = null;
      return parsed;
    }
    lastError = 'Direct LLM: format respons tidak valid';
    return null;
  }

  Map<String, dynamic>? _decodeJsonObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } catch (_) {
      return null;
    }
  }

  TranslationResult? _parseLlmTranslation(Map data) {
    final trans = (data['translation'] as String?)?.trim();
    if (trans == null || trans.isEmpty) return null;
    final tokens = _tokensFromJson(data['tokens']);
    return TranslationResult(
      translation: trans,
      pinyin: (data['pinyin'] as String?)?.trim().isNotEmpty == true
          ? data['pinyin'] as String
          : null,
      alternatives: _tokensFromJson(data['alternatives']),
      tokens: tokens.map(_enrich).toList(),
    );
  }

  List<TranslateToken> _tokensFromJson(Object? value) {
    if (value is! List) return const [];
    return value
        .map((e) {
          if (e is Map) {
            return TranslateToken.fromJson(Map<String, dynamic>.from(e));
          }
          final hanzi = _stringish(e);
          return hanzi.isEmpty ? null : TranslateToken(hanzi: hanzi);
        })
        .nonNulls
        .toList();
  }

  // === Dictionary fallback (offline) ===

  static const _commonIdCandidates = <String, List<_ZhCandidate>>{
    'halo': [
      _ZhCandidate('你好', 'nǐ hǎo', 'sapaan umum'),
      _ZhCandidate('喂', 'wèi', 'halo di telepon'),
      _ZhCandidate('哈喽', 'hā lou', 'sapaan serapan kasual'),
    ],
    'hai': [
      _ZhCandidate('你好', 'nǐ hǎo', 'sapaan umum'),
      _ZhCandidate('哈喽', 'hā lou', 'sapaan kasual'),
    ],
    'apa kabar': [
      _ZhCandidate('你好吗', 'nǐ hǎo ma', 'apa kabar'),
      _ZhCandidate(
        '你最近怎么样',
        'nǐ zuìjìn zěnmeyàng',
        'gimana kabarmu akhir-akhir ini',
      ),
    ],
    'terima kasih': [
      _ZhCandidate('谢谢', 'xièxie', 'terima kasih umum'),
      _ZhCandidate('多谢', 'duō xiè', 'banyak terima kasih'),
      _ZhCandidate('感谢', 'gǎnxiè', 'berterima kasih, lebih formal'),
    ],
    'makasih': [
      _ZhCandidate('谢谢', 'xièxie', 'terima kasih umum'),
      _ZhCandidate('多谢', 'duō xiè', 'banyak terima kasih'),
    ],
    'sampai jumpa': [
      _ZhCandidate('再见', 'zàijiàn', 'sampai jumpa umum'),
      _ZhCandidate('回头见', 'huítóu jiàn', 'sampai ketemu nanti, kasual'),
    ],
    'selamat pagi': [
      _ZhCandidate('早上好', 'zǎoshang hǎo', 'selamat pagi'),
      _ZhCandidate('早', 'zǎo', 'pagi, kasual'),
    ],
    'makan': [
      _ZhCandidate('吃', 'chī', 'makan, paling umum'),
      _ZhCandidate('吃饭', 'chīfàn', 'makan nasi / makan sehari-hari'),
      _ZhCandidate('用餐', 'yòngcān', 'bersantap, lebih formal'),
      _ZhCandidate('进食', 'jìnshí', 'makan, teknis/medis'),
    ],
    'makanan': [
      _ZhCandidate('食物', 'shíwù', 'makanan, paling umum'),
      _ZhCandidate('饭菜', 'fàncài', 'hidangan / makanan rumahan'),
      _ZhCandidate('食品', 'shípǐn', 'produk makanan'),
    ],
    'minum': [
      _ZhCandidate('喝', 'hē', 'minum, paling umum'),
      _ZhCandidate('喝水', 'hē shuǐ', 'minum air'),
      _ZhCandidate('饮用', 'yǐnyòng', 'minum/mengonsumsi, formal'),
    ],
    'pergi': [
      _ZhCandidate('去', 'qù', 'pergi'),
      _ZhCandidate('走', 'zǒu', 'pergi/jalan, tergantung konteks'),
    ],
    'datang': [
      _ZhCandidate('来', 'lái', 'datang'),
      _ZhCandidate('来到', 'láidào', 'datang ke suatu tempat'),
    ],
    'lihat': [
      _ZhCandidate('看', 'kàn', 'lihat/melihat, paling umum'),
      _ZhCandidate('看见', 'kànjiàn', 'melihat/terlihat'),
    ],
    'dengar': [
      _ZhCandidate('听', 'tīng', 'dengar/mendengar'),
      _ZhCandidate('听见', 'tīngjiàn', 'terdengar'),
    ],
    'bicara': [
      _ZhCandidate('说', 'shuō', 'bicara/bilang, paling umum'),
      _ZhCandidate('讲话', 'jiǎnghuà', 'berbicara'),
    ],
    'beli': [_ZhCandidate('买', 'mǎi', 'beli')],
    'jual': [_ZhCandidate('卖', 'mài', 'jual')],
    'suka': [
      _ZhCandidate('喜欢', 'xǐhuān', 'suka'),
      _ZhCandidate('爱', 'ài', 'suka/cinta, lebih kuat'),
    ],
  };

  /// Common Indonesian phrases → Chinese. Checked first before word-by-word
  /// lookup, so "apa kabar" → 你好吗 instead of 何获悉.
  static const _idPhraseMap = {
    'apa kabar': ('你好吗', 'nǐ hǎo ma'),
    'hari ini': ('今天', 'jīntiān'),
    'terima kasih': ('谢谢', 'xièxie'),
    'terima kasih banyak': ('非常感谢', 'fēicháng gǎnxiè'),
    'sama sekali': ('完全', 'wánquán'),
    'selamat pagi': ('早上好', 'zǎoshang hǎo'),
    'selamat malam': ('晚上好', 'wǎnshang hǎo'),
    'selamat tinggal': ('再见', 'zàijiàn'),
    'sampai jumpa': ('再见', 'zàijiàn'),
    'apa ini': ('这是什么', 'zhè shì shénme'),
    'apa itu': ('那是什么', 'nà shì shénme'),
    'berapa umur': ('几岁', 'jǐ suì'),
    'nama saya': ('我叫', 'wǒ jiào'),
    'saya tidak': ('我不', 'wǒ bù'),
    'dia adalah': ('他是', 'tā shì'),
    'dia bukan': ('他不是', 'tā bù shì'),
    'saya mau': ('我要', 'wǒ yào'),
    'saya ingin': ('我想', 'wǒ xiǎng'),
    'saya suka': ('我喜欢', 'wǒ xǐhuān'),
    'saya tidak suka': ('我不喜欢', 'wǒ bù xǐhuān'),
    'saya bisa': ('我会', 'wǒ huì'),
    'saya tidak bisa': ('我不会', 'wǒ bù huì'),
    'tidak apa': ('没关系', 'méi guānxi'),
    'tidak masalah': ('没问题', 'méi wèntí'),
    'tidak tahu': ('不知道', 'bù zhīdào'),
    'maafkan saya': ('对不起', 'duìbuqǐ'),
  };

  /// Common Chinese particles/grammar → natural Indonesian.
  static const _zhParticleMap = {
    '吗': 'kah',
    '呢': 'lalu',
    '的': '',
    '了': 'sudah',
    '在': 'sedang',
    '和': 'dan',
    '是': 'adalah',
    '不': 'tidak',
    '没': 'tidak',
    '都': 'semua',
    '也': 'juga',
    '很': 'sangat',
    '太': 'terlalu',
    '这': 'ini',
    '那': 'itu',
    '哪': 'mana',
    '谁': 'siapa',
    '什么': 'apa',
    '怎么': 'bagaimana',
    '为什么': 'kenapa',
    '多少': 'berapa',
    '几': 'berapa',
    '可以': 'boleh',
    '能': 'bisa',
    '会': 'bisa',
    '想': 'ingin',
    '要': 'mau',
    '喜欢': 'suka',
    '爱': 'cinta',
    '吃': 'makan',
    '喝': 'minum',
    '看': 'lihat',
    '听': 'dengar',
    '说': 'bilang',
    '读': 'baca',
    '写': 'tulis',
    '学': 'belajar',
    '买': 'beli',
    '卖': 'jual',
    '去': 'pergi',
    '来': 'datang',
    '做': 'lakukan',
    '有': 'punya',
    '没有': 'tidak punya',
  };

  TranslationResult _dictTranslateZhToId(String text, String track) {
    final tokens = <TranslateToken>[];
    final meanings = <String>[];
    final pinyins = <String>[];
    final cjk = RegExp(r'[一-鿿㐀-䶿]');
    const maxLen = 8;
    int i = 0;

    while (i < text.length) {
      if (!cjk.hasMatch(text[i])) {
        i++;
        continue;
      }
      _DictEntry? hit;
      int hitLen = 0;
      final limit = maxLen < text.length - i ? maxLen : text.length - i;
      for (int l = limit; l >= 1; l--) {
        final cand = text.substring(i, i + l);
        final e = _dict[cand];
        if (e != null) {
          hit = e;
          hitLen = l;
          break;
        }
      }
      if (hit != null) {
        final hanzi = _displayHanzi(hit, track);
        // Use particle map for natural translation, else split meanings.
        final allMeanings = VocabEntry.splitMeanings(hit.meaning);
        final primaryMeaning =
            _zhParticleMap[hit.simplified] ??
            (allMeanings.isNotEmpty ? allMeanings.first : '');
        final alts = allMeanings.length > 1
            ? allMeanings.sublist(1)
            : <String>[];
        tokens.add(
          TranslateToken(
            hanzi: hanzi,
            pinyin: hit.pinyin,
            meaning: primaryMeaning,
            hsk: hit.hsk,
            altMeanings: _zhParticleMap[hit.simplified] != null
                ? alts
                : const [],
          ),
        );
        if (primaryMeaning.isNotEmpty) meanings.add(primaryMeaning);
        if (hit.pinyin.isNotEmpty) pinyins.add(hit.pinyin);
        i += hitLen;
      } else {
        tokens.add(TranslateToken(hanzi: text[i]));
        meanings.add(text[i]);
        i++;
      }
    }
    return TranslationResult(
      translation: meanings.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
      pinyin: pinyins.join(' '),
      tokens: tokens,
    );
  }

  TranslationResult? _dictTranslateIdToZh(String text, String track) {
    final lower = _normalizeIdText(text);

    final common = _commonIdCandidates[lower];
    if (common != null && common.isNotEmpty) {
      final primary = common.first;
      final alternatives = common.skip(1).map((candidate) {
        final hanzi = track == 'traditional'
            ? _toTraditional(candidate.hanzi)
            : candidate.hanzi;
        return TranslateToken(
          hanzi: hanzi,
          pinyin: candidate.pinyin,
          meaning: candidate.note,
        );
      }).toList();
      final hanzi = track == 'traditional'
          ? _toTraditional(primary.hanzi)
          : primary.hanzi;
      return TranslationResult(
        translation: hanzi,
        pinyin: primary.pinyin,
        alternatives: alternatives,
        tokens: [
          TranslateToken(hanzi: hanzi, pinyin: primary.pinyin, meaning: lower),
        ],
      );
    }

    // 1. Greedy phrase + word segmentation. This keeps multi-word input intact:
    // "saya suka makan" -> "我喜欢吃", not just "我喜欢".
    final phraseKeys = _idPhraseMap.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final idIndex = <String, List<_DictEntry>>{};
    final seenEntries = <String>{};
    for (final e in _dict.values) {
      if (!seenEntries.add(e.simplified)) continue;
      final m = e.meaning.toLowerCase();
      if (m.isEmpty) continue;
      for (final part in VocabEntry.splitMeanings(m)) {
        final w = part.trim();
        if (w.length >= 2) idIndex.putIfAbsent(w, () => []).add(e);
      }
    }

    final words = text
        .split(RegExp(r'\s+'))
        .map(_cleanIdWord)
        .where((word) => word.isNotEmpty)
        .toList();
    final tokens = <TranslateToken>[];
    final results = <String>[];
    final alternatives = <TranslateToken>[];
    var translatedAny = false;
    var i = 0;

    while (i < words.length) {
      final remaining = words.sublist(i).join(' ');
      String? matchedPhrase;
      for (final phrase in phraseKeys) {
        if (remaining == phrase || remaining.startsWith('$phrase ')) {
          matchedPhrase = phrase;
          break;
        }
      }
      if (matchedPhrase != null) {
        final (hanzi, pinyin) = _idPhraseMap[matchedPhrase]!;
        final display = track == 'traditional' ? _toTraditional(hanzi) : hanzi;
        tokens.add(
          TranslateToken(
            hanzi: display,
            pinyin: pinyin,
            meaning: matchedPhrase,
          ),
        );
        results.add(display);
        translatedAny = true;
        i += matchedPhrase.split(RegExp(r'\s+')).length;
        continue;
      }

      final word = words[i];
      final w = word.toLowerCase();
      if (w.isEmpty) {
        i++;
        continue;
      }
      final commonWord = _commonIdCandidates[w];
      if (commonWord != null && commonWord.isNotEmpty) {
        final primary = commonWord.first;
        final hanzi = track == 'traditional'
            ? _toTraditional(primary.hanzi)
            : primary.hanzi;
        tokens.add(
          TranslateToken(hanzi: hanzi, pinyin: primary.pinyin, meaning: w),
        );
        results.add(hanzi);
        translatedAny = true;
        if (words.length == 1) {
          alternatives.addAll(
            commonWord.skip(1).map((candidate) {
              final altHanzi = track == 'traditional'
                  ? _toTraditional(candidate.hanzi)
                  : candidate.hanzi;
              return TranslateToken(
                hanzi: altHanzi,
                pinyin: candidate.pinyin,
                meaning: candidate.note,
              );
            }),
          );
        }
        i++;
        continue;
      }
      final hits = idIndex[w];
      _DictEntry? best;
      if (hits != null && hits.isNotEmpty) {
        final ranked = _rankIdHits(hits, w);
        best = ranked.first;
        if (words.length == 1) {
          alternatives.addAll(
            ranked.skip(1).take(4).map((e) => _entryToken(e, track)),
          );
        }
      }
      if (best != null) {
        final hanzi = _displayHanzi(best, track);
        tokens.add(_entryToken(best, track));
        results.add(hanzi);
        translatedAny = true;
      } else {
        tokens.add(TranslateToken(hanzi: word, meaning: word));
        results.add(word);
      }
      i++;
    }
    if (!translatedAny) {
      lastError = 'Tidak ada kata Indonesia yang cocok di kamus offline.';
      return null;
    }
    return TranslationResult(
      translation: results.join(),
      pinyin: tokens.map((t) => t.pinyin).where((p) => p.isNotEmpty).join(' '),
      alternatives: alternatives,
      tokens: tokens,
    );
  }

  List<_DictEntry> _rankIdHits(List<_DictEntry> hits, String query) {
    final deduped = <String, _DictEntry>{};
    for (final hit in hits) {
      deduped.putIfAbsent(hit.simplified, () => hit);
    }
    final ranked = deduped.values.toList();
    ranked.sort((a, b) {
      final scoreA = _idHitScore(a, query);
      final scoreB = _idHitScore(b, query);
      if (scoreA != scoreB) return scoreA.compareTo(scoreB);
      return a.simplified.compareTo(b.simplified);
    });
    return ranked;
  }

  int _idHitScore(_DictEntry e, String query) {
    final meanings = VocabEntry.splitMeanings(e.meaning.toLowerCase());
    final primary = e.primaryMeaning.toLowerCase();
    var score = 0;
    if (primary == query) {
      score -= 600;
    } else if (meanings.contains(query)) {
      score -= 420;
    } else if (meanings.any((m) => _meaningWords(m).contains(query))) {
      score -= 120;
    }

    score += (e.hsk ?? 20) * 20;
    score += e.simplified.length * 8;
    if (RegExp(r'\d$').hasMatch(e.simplified)) score += 180;
    if (_looksLiteral(e.meaning)) score += 90;
    return score;
  }

  Set<String> _meaningWords(String meaning) =>
      meaning.split(RegExp(r'[\s/(),]+')).where((w) => w.isNotEmpty).toSet();

  String _normalizeIdText(String text) => text
      .split(RegExp(r'\s+'))
      .map(_cleanIdWord)
      .where((word) => word.isNotEmpty)
      .join(' ');

  String _cleanIdWord(String word) =>
      word.toLowerCase().replaceAll(RegExp(r'^[.,!?;:]+|[.,!?;:]+$'), '');

  bool _looksLiteral(String meaning) {
    final m = meaning.toLowerCase();
    return m.contains('mulut makan') ||
        m.contains('kekuatan makan') ||
        m.contains('makan terkejut') ||
        m.contains('muda anak') ||
        m.contains('sifat anak');
  }

  TranslateToken _entryToken(_DictEntry e, String track) {
    final allMeanings = VocabEntry.splitMeanings(e.meaning);
    return TranslateToken(
      hanzi: _displayHanzi(e, track),
      pinyin: e.pinyin,
      meaning: allMeanings.isNotEmpty ? allMeanings.first : e.meaning,
      altMeanings: allMeanings.length > 1 ? allMeanings.sublist(1) : const [],
      hsk: e.hsk,
    );
  }

  String _displayHanzi(_DictEntry e, String track) =>
      track == 'traditional' ? e.traditional : e.simplified;

  /// Convert simplified hanzi to traditional using the dictionary.
  String _toTraditional(String simplified) {
    final out = StringBuffer();
    for (final ch in simplified.split('')) {
      final e = _dict[ch];
      out.write(e?.traditional ?? _fallbackSimpToTrad[ch] ?? ch);
    }
    return VocabEntry.normalizeModernTraditional(out.toString());
  }
}

class _DictEntry {
  final String simplified;
  final String traditional;
  final String pinyin;
  final String meaning;
  final int? hsk;
  const _DictEntry({
    required this.simplified,
    required this.traditional,
    this.pinyin = '',
    this.meaning = '',
    this.hsk,
  });

  String get primaryMeaning {
    final parts = VocabEntry.splitMeanings(meaning);
    return parts.isEmpty ? meaning.trim() : parts.first;
  }
}

class _ZhCandidate {
  final String hanzi;
  final String pinyin;
  final String note;
  const _ZhCandidate(this.hanzi, this.pinyin, this.note);
}
