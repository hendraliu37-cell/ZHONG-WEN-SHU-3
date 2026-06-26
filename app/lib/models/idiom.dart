/// Satu entri idiom/peribahasa untuk bank bahasa.
class Idiom {
  final String simplified;   // s
  final String traditional;  // t
  final String pinyin;       // py
  final String zhuyin;       // zy
  final String meaning;      // m  (makna/kiasan)
  final String literal;      // lit (arti harfiah)
  final String category;     // cat: 'chengyu' | 'yanyu' | 'suyu'
  final String origin;       // origin (opsional)
  final String exampleS;     // exs
  final String exampleT;     // ext
  final String exampleId;    // exi
  final int tone;

  const Idiom({
    required this.simplified,
    required this.traditional,
    required this.pinyin,
    this.zhuyin = '',
    required this.meaning,
    this.literal = '',
    required this.category,
    this.origin = '',
    this.exampleS = '',
    this.exampleT = '',
    this.exampleId = '',
    this.tone = 1,
  });

  factory Idiom.fromJson(Map<String, dynamic> j) => Idiom(
        simplified: (j['s'] ?? '') as String,
        traditional: (j['t'] ?? j['s'] ?? '') as String,
        pinyin: (j['py'] ?? '') as String,
        zhuyin: (j['zy'] ?? '') as String,
        meaning: (j['m'] ?? '') as String,
        literal: (j['lit'] ?? '') as String,
        category: (j['cat'] ?? 'chengyu') as String,
        origin: (j['origin'] ?? '') as String,
        exampleS: (j['exs'] ?? '') as String,
        exampleT: (j['ext'] ?? '') as String,
        exampleId: (j['exi'] ?? '') as String,
        tone: (j['tone'] ?? 1) as int,
      );
}
