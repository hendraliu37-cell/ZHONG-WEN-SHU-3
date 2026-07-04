/// A single dual-standard vocabulary entry.
///
/// Non-negotiable rule (PRD §4.1): every entry carries 简 + 繁 + 拼音 + 注音.
/// A track switch is a pure display toggle, never a data migration.
class VocabEntry {
  final String simplified; // 简体  (s)
  final String traditional; // 繁體  (t)
  final String pinyin; // 拼音  (py)
  final String zhuyin; // 注音  (zy)
  final String meaning; // arti (Bahasa Indonesia)  (m)
  final String exampleS; // contoh kalimat 简体  (exs)
  final String exampleT; // contoh kalimat 繁體  (ext)
  final String exampleId; // terjemahan contoh  (exi)
  final int tone; // 1–4 (5 = neutral) for the headword
  final int? hskLevel; // 1–6 or null
  final int? tocflLevel; // 1–7 or null

  const VocabEntry({
    required this.simplified,
    required this.traditional,
    required this.pinyin,
    this.zhuyin = '',
    required this.meaning,
    this.exampleS = '',
    this.exampleT = '',
    this.exampleId = '',
    this.tone = 1,
    this.hskLevel,
    this.tocflLevel,
  });

  /// Pleco-style meanings: one headword can carry several Indonesian glosses.
  ///
  /// Existing packs use separators such as `/`, `;`, commas, or new lines.
  /// Keep the stored [meaning] string intact for backward compatibility, but
  /// use these helpers whenever the app needs one display answer or tolerant
  /// answer matching.
  List<String> get meanings => splitMeanings(meaning);

  String get primaryMeaning =>
      meanings.isEmpty ? meaning.trim() : meanings.first;

  List<String> get alternativeMeanings =>
      meanings.length <= 1 ? const [] : meanings.sublist(1);

  String get meaningPreview =>
      meanings.isEmpty ? meaning.trim() : meanings.join(' / ');

  bool matchesMeaning(String input) {
    final n = normalizeMeaning(input);
    if (n.isEmpty) return false;
    return meanings.any((m) => normalizeMeaning(m) == n);
  }

  factory VocabEntry.fromJson(Map<String, dynamic> j) => VocabEntry(
    simplified: _string(j['s'] ?? j['simplified']),
    traditional: normalizeModernTraditional(
      _string(j['t'] ?? j['traditional'] ?? j['s'] ?? j['simplified']),
    ),
    pinyin: _string(j['py'] ?? j['pinyin']),
    zhuyin: _string(j['zy'] ?? j['zhuyin']),
    meaning: _string(j['m'] ?? j['meaning']),
    exampleS: _string(j['exs'] ?? j['example_s']),
    exampleT: normalizeModernTraditional(_string(j['ext'] ?? j['example_t'])),
    exampleId: _string(j['exi'] ?? j['example_id']),
    tone: _tone(j['tone']),
    hskLevel: _intish(j['hsk']),
    tocflLevel: _intish(j['tocfl']),
  );

  Map<String, dynamic> toJson() => {
    's': simplified,
    't': traditional,
    'py': pinyin,
    'zy': zhuyin,
    'm': meaning,
    'exs': exampleS,
    'ext': exampleT,
    'exi': exampleId,
    'tone': tone,
    if (hskLevel != null) 'hsk': hskLevel,
    if (tocflLevel != null) 'tocfl': tocflLevel,
  };

  static List<String> splitMeanings(String raw) {
    final seen = <String>{};
    final parts = raw
        .split(RegExp(r'\r?\n|;|/|,'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where((part) => seen.add(normalizeMeaning(part)))
        .toList();
    return parts;
  }

  static String normalizeMeaning(String raw) => raw
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _string(Object? value) => value?.toString() ?? '';

  static int? _intish(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }

  static int _tone(Object? value) {
    final parsed = _intish(value);
    if (parsed == null) return 1;
    if (parsed == 0) return 5;
    return parsed >= 1 && parsed <= 5 ? parsed : 1;
  }

  static String normalizeModernTraditional(String value) {
    const replacements = {
      '喫': '吃',
      '爲': '為',
      '裏': '裡',
      '牀': '床',
      '麪': '麵',
      '着': '著',
      '祇': '只',
    };
    var out = value;
    for (final entry in replacements.entries) {
      out = out.replaceAll(entry.key, entry.value);
    }
    return out;
  }
}
