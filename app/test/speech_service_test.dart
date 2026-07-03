import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/services/speech.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpeechService tuning', () {
    test('uses full volume and learner-friendly slow rates', () {
      expect(SpeechService.speechVolume, 1.0);
      expect(SpeechService.neuralPlaybackRate, lessThanOrEqualTo(0.72));
      expect(SpeechService.osSpeechRate, lessThanOrEqualTo(0.28));
      expect(SpeechService.osPitch, closeTo(1.04, 0.001));
    });

    test('dispose disables later playback requests', () {
      final speech = SpeechService();

      speech.dispose();

      expect(speech.enabledForTest, isFalse);
      expect(speech.disposedForTest, isTrue);
    });

    test('neural response parser accepts common audio payload shapes', () {
      expect(parseTtsAudioResponseForTest({'audio': 'AQID'}), [1, 2, 3]);
      expect(parseTtsAudioResponseForTest('{"audio":"BAU="}'), [4, 5]);
      expect(parseTtsAudioResponseForTest({'audio_base64': 'Bgc='}), [6, 7]);
      expect(parseTtsAudioResponseForTest('CAk='), [8, 9]);
      expect(parseTtsAudioResponseForTest('data:audio/mpeg;base64,Cgs='), [
        10,
        11,
      ]);
      expect(
        parseTtsAudioResponseForTest({'audio': 'data:audio/mp3;base64,DA0='}),
        [12, 13],
      );
      expect(parseTtsAudioResponseForTest({'audio': 'not-base64'}), isEmpty);
    });
  });
}
