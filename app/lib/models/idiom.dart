/// Satu entri idiom/peribahasa untuk bank bahasa.
class Idiom {
  final String simplified; // s
  final String traditional; // t
  final String pinyin; // py
  final String zhuyin; // zy
  final String meaning; // m  (makna/kiasan)
  final String literal; // lit (arti harfiah)
  final String category; // cat: 'chengyu' | 'yanyu' | 'suyu'
  final String origin; // origin (opsional)
  final String exampleS; // exs
  final String exampleT; // ext
  final String exampleId; // exi
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

  factory Idiom.fromJson(Map<String, dynamic> j) {
    final simplified = _string(j['s']);
    return Idiom(
      simplified: simplified,
      traditional: _string(j['t']).isEmpty ? simplified : _string(j['t']),
      pinyin: _string(j['py']),
      zhuyin: _string(j['zy']),
      meaning: _string(j['m']),
      literal: _string(j['lit']),
      category: _category(j['cat']),
      origin: _string(j['origin']),
      exampleS: _string(j['exs']),
      exampleT: _string(j['ext']),
      exampleId: _string(j['exi']),
      tone: _tone(j['tone']),
    );
  }
}

String _string(Object? value) => value?.toString().trim() ?? '';

String _category(Object? value) {
  const allowed = {'chengyu', 'yanyu', 'suyu'};
  final text = _string(value).toLowerCase();
  return allowed.contains(text) ? text : 'chengyu';
}

int _tone(Object? value) {
  int? parsed;
  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else if (value is String) {
    final text = value.trim();
    parsed = int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }
  if (parsed == null || parsed < 1 || parsed > 5) return 1;
  return parsed;
}
