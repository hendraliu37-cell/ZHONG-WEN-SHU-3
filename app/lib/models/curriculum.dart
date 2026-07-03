import 'dart:convert';

/// Satu topik materi harian dari Guru.
class DailyMaterial {
  final String topic;
  final List<VocabItem> vocab;
  final List<String> sentences;
  final String exercise;

  const DailyMaterial({
    required this.topic,
    required this.vocab,
    required this.sentences,
    required this.exercise,
  });

  factory DailyMaterial.fromJson(Map<String, dynamic> j) => DailyMaterial(
    topic: _string(j['topic']),
    vocab: _list(j['vocab'])
        .whereType<Map>()
        .map((v) => VocabItem.fromJson(Map<String, dynamic>.from(v)))
        .where((v) => v.hanzi.isNotEmpty || v.meaning.isNotEmpty)
        .toList(),
    sentences: _list(j['sentences'])
        .where((s) => s != null)
        .map((s) => s.toString().trim())
        .where((s) => s.isNotEmpty)
        .toList(),
    exercise: _string(j['exercise']),
  );

  String get summary {
    if (vocab.isEmpty) return topic;
    final words = vocab.map((v) => v.hanzi).take(4).join(', ');
    return words;
  }
}

class VocabItem {
  final String hanzi;
  final String pinyin;
  final String meaning;

  const VocabItem({
    required this.hanzi,
    required this.pinyin,
    required this.meaning,
  });

  factory VocabItem.fromJson(Map<String, dynamic> j) => VocabItem(
    hanzi: _string(j['hanzi']),
    pinyin: _string(j['pinyin']),
    meaning: _string(j['meaning']),
  );
}

String _string(Object? value) => value?.toString().trim() ?? '';

List<Object?> _list(Object? value) {
  if (value is List) return value;
  if (value is String) {
    final text = value.trim();
    if (!text.startsWith('[')) return const <Object?>[];
    try {
      final decoded = jsonDecode(text);
      return decoded is List ? decoded : const <Object?>[];
    } catch (_) {
      return const <Object?>[];
    }
  }
  return const <Object?>[];
}
