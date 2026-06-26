import '../models/vocab.dart';

/// Starter vocabulary, ported field-for-field from the prototype `VOCAB`.
/// These seed the built-in demo decks so the app is usable before any pack
/// download. (Downloadable HSK/TOCFL packs live in `assets/packs/`.)
const List<VocabEntry> seedVocab = [
  VocabEntry(simplified: '你好', traditional: '你好', pinyin: 'nǐ hǎo', zhuyin: 'ㄋㄧˇ ㄏㄠˇ', meaning: 'halo / apa kabar', exampleS: '你好，老师！', exampleT: '你好，老師！', exampleId: 'Halo, Bu/Pak Guru!', tone: 3, hskLevel: 1),
  VocabEntry(simplified: '老师', traditional: '老師', pinyin: 'lǎoshī', zhuyin: 'ㄌㄠˇ ㄕ', meaning: 'guru', exampleS: '她是我的老师。', exampleT: '她是我的老師。', exampleId: 'Dia guru saya.', tone: 3, hskLevel: 1),
  VocabEntry(simplified: '学生', traditional: '學生', pinyin: 'xuésheng', zhuyin: 'ㄒㄩㄝˊ ㄕㄥ', meaning: 'murid / pelajar', exampleS: '我是学生。', exampleT: '我是學生。', exampleId: 'Saya seorang murid.', tone: 2, hskLevel: 1),
  VocabEntry(simplified: '谢谢', traditional: '謝謝', pinyin: 'xièxie', zhuyin: 'ㄒㄧㄝˋ ㄒㄧㄝ˙', meaning: 'terima kasih', exampleS: '谢谢你！', exampleT: '謝謝你！', exampleId: 'Terima kasih!', tone: 4, hskLevel: 1),
  VocabEntry(simplified: '中文', traditional: '中文', pinyin: 'zhōngwén', zhuyin: 'ㄓㄨㄥ ㄨㄣˊ', meaning: 'bahasa Mandarin', exampleS: '我学中文。', exampleT: '我學中文。', exampleId: 'Saya belajar bahasa Mandarin.', tone: 1, hskLevel: 2),
  VocabEntry(simplified: '书', traditional: '書', pinyin: 'shū', zhuyin: 'ㄕㄨ', meaning: 'buku', exampleS: '这本书很好。', exampleT: '這本書很好。', exampleId: 'Buku ini bagus.', tone: 1, hskLevel: 1),
  VocabEntry(simplified: '朋友', traditional: '朋友', pinyin: 'péngyou', zhuyin: 'ㄆㄥˊ ㄧㄡ˙', meaning: 'teman', exampleS: '他是我的朋友。', exampleT: '他是我的朋友。', exampleId: 'Dia teman saya.', tone: 2, hskLevel: 1),
  VocabEntry(simplified: '喜欢', traditional: '喜歡', pinyin: 'xǐhuan', zhuyin: 'ㄒㄧˇ ㄏㄨㄢ˙', meaning: 'suka', exampleS: '我喜欢中文。', exampleT: '我喜歡中文。', exampleId: 'Saya suka bahasa Mandarin.', tone: 3, hskLevel: 1),
  VocabEntry(simplified: '苹果', traditional: '蘋果', pinyin: 'píngguǒ', zhuyin: 'ㄆㄧㄥˊ ㄍㄨㄛˇ', meaning: 'apel', exampleS: '我吃苹果。', exampleT: '我吃蘋果。', exampleId: 'Saya makan apel.', tone: 2, hskLevel: 1),
  VocabEntry(simplified: '水', traditional: '水', pinyin: 'shuǐ', zhuyin: 'ㄕㄨㄟˇ', meaning: 'air', exampleS: '我喝水。', exampleT: '我喝水。', exampleId: 'Saya minum air.', tone: 3, hskLevel: 1),
  VocabEntry(simplified: '学习', traditional: '學習', pinyin: 'xuéxí', zhuyin: 'ㄒㄩㄝˊ ㄒㄧˊ', meaning: 'belajar', exampleS: '我学习中文。', exampleT: '我學習中文。', exampleId: 'Saya belajar bahasa Mandarin.', tone: 2, hskLevel: 1),
  VocabEntry(simplified: '看', traditional: '看', pinyin: 'kàn', zhuyin: 'ㄎㄢˋ', meaning: 'melihat / membaca', exampleS: '我看书。', exampleT: '我看書。', exampleId: 'Saya membaca buku.', tone: 4, hskLevel: 1),
  VocabEntry(simplified: '吃', traditional: '吃', pinyin: 'chī', zhuyin: 'ㄔ', meaning: 'makan', exampleS: '我吃苹果。', exampleT: '我吃蘋果。', exampleId: 'Saya makan apel.', tone: 1, hskLevel: 1),
  VocabEntry(simplified: '喝', traditional: '喝', pinyin: 'hē', zhuyin: 'ㄏㄜ', meaning: 'minum', exampleS: '我喝水。', exampleT: '我喝水。', exampleId: 'Saya minum air.', tone: 1, hskLevel: 1),
];

/// Definition of the built-in demo decks: (idx, name, [indices into seedVocab]).
const List<({String idx, String name, List<int> cards})> seedDeckDefs = [
  (idx: '01', name: 'Sapaan & Sopan Santun', cards: [0, 3, 6]),
  (idx: '02', name: 'Ruang Kelas', cards: [1, 2, 5, 4, 10]),
  (idx: '03', name: 'Makanan & Buah', cards: [8, 9, 12, 13]),
  (idx: '04', name: 'Kata Kerja Harian', cards: [7, 11, 12, 13]),
];

/// Single-syllable words with unambiguous tones for the Tebak Nada game.
const List<({String han, String pinyin, int tone})> toneBank = [
  (han: '妈', pinyin: 'mā', tone: 1),
  (han: '国', pinyin: 'guó', tone: 2),
  (han: '好', pinyin: 'hǎo', tone: 3),
  (han: '是', pinyin: 'shì', tone: 4),
  (han: '书', pinyin: 'shū', tone: 1),
  (han: '茶', pinyin: 'chá', tone: 2),
  (han: '水', pinyin: 'shuǐ', tone: 3),
  (han: '看', pinyin: 'kàn', tone: 4),
];

/// Mastery buckets (handoff §2). Index = mastery 0–3.
const List<({String label, int color})> masteryLevels = [
  (label: 'Baru', color: 0xFF9A948A),
  (label: 'Perlu latihan', color: 0xFFB23B2E),
  (label: 'Cukup', color: 0xFFB8862F),
  (label: 'Mahir', color: 0xFF3A9E6A),
];
