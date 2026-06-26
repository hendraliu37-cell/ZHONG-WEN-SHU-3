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
        topic: (j['topic'] ?? '') as String,
        vocab: ((j['vocab'] ?? []) as List)
            .map((v) => VocabItem.fromJson(v as Map<String, dynamic>))
            .toList(),
        sentences: ((j['sentences'] ?? []) as List).map((s) => s.toString()).toList(),
        exercise: (j['exercise'] ?? '') as String,
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
        hanzi: (j['hanzi'] ?? '') as String,
        pinyin: (j['pinyin'] ?? '') as String,
        meaning: (j['meaning'] ?? '') as String,
      );
}
