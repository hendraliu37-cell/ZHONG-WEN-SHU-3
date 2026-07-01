import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/services/speech.dart';

void main() {
  group('SpeechService tuning', () {
    test('uses full volume and learner-friendly slow rates', () {
      expect(SpeechService.speechVolume, 1.0);
      expect(SpeechService.neuralPlaybackRate, lessThanOrEqualTo(0.72));
      expect(SpeechService.osSpeechRate, lessThanOrEqualTo(0.28));
      expect(SpeechService.osPitch, closeTo(1.04, 0.001));
    });
  });
}
