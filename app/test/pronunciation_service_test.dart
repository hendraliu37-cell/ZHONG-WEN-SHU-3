import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/services/pronunciation_service.dart';

void main() {
  test('parses pronunciation scoring response safely', () {
    final result = PronunciationResult.fromJson({
      'transcript': '你好',
      'score': 87.6,
      'words': [
        {'word': '你', 'confidence': 91.2},
        {'word': '好', 'confidence': 84},
      ],
    });

    expect(result.transcript, '你好');
    expect(result.score, 88);
    expect(result.words.map((w) => w.word), ['你', '好']);
    expect(result.words.map((w) => w.confidence), [91, 84]);
  });

  test('clamps invalid pronunciation scores', () {
    expect(PronunciationResult.fromJson({'score': 140}).score, 100);
    expect(PronunciationResult.fromJson({'score': -5}).score, 0);
  });
}
