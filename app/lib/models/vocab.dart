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
    simplified: (j['s'] ?? j['simplified'] ?? '') as String,
    traditional: (j['t'] ?? j['traditional'] ?? j['s'] ?? '') as String,
    pinyin: (j['py'] ?? j['pinyin'] ?? '') as String,
    zhuyin: (j['zy'] ?? j['zhuyin'] ?? '') as String,
    meaning: (j['m'] ?? j['meaning'] ?? '') as String,
    exampleS: (j['exs'] ?? j['example_s'] ?? '') as String,
    exampleT: (j['ext'] ?? j['example_t'] ?? '') as String,
    exampleId: (j['exi'] ?? j['example_id'] ?? '') as String,
    tone: (j['tone'] ?? 1) as int,
    hskLevel: j['hsk'] as int?,
    tocflLevel: j['tocfl'] as int?,
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
}
