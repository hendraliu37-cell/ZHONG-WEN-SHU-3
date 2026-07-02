import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhongwen_shu/services/llm_service.dart';
import 'package:zhongwen_shu/state/app_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          recordChannel,
          (MethodCall call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  test('Guru display text follows traditional profile variant', () {
    final text = formatTutorReplyForDisplay(
      'Ringkas: 我喜欢这本书，也想吃饭。',
      track: 'traditional',
      primary: 'traditional',
    );

    expect(text, contains('我喜歡這本書'));
    expect(text, contains('吃飯'));
    expect(text, isNot(contains('喜欢')));
    expect(text, isNot(contains('这')));
    expect(text, isNot(contains('饭')));
  });

  test('Guru display text strips noisy markdown bullets', () {
    final text = formatTutorReplyForDisplay(
      '''```markdown
# Jawaban
- Ringkas: halo.
1. Contoh: 你好 (ni hao) = halo.
```''',
      track: 'simplified',
      primary: 'simplified',
    );

    expect(text.split('\n'), ['Ringkas: halo.', 'Contoh: 你好 (ni hao) = halo.']);
  });

  test('Guru display text gives unlabeled replies a tidy structure', () {
    final text = formatTutorReplyForDisplay(
      '''Xiang berarti ingin atau mau.
我想吃饭 (wo3 xiang3 chi1 fan4) = aku mau makan.
Coba bikin satu kalimat pakai xiang?''',
      track: 'simplified',
      primary: 'simplified',
    );

    expect(text.split('\n'), [
      'Ringkas: Xiang berarti ingin atau mau.',
      'Contoh: 我想吃饭 (wo3 xiang3 chi1 fan4) = aku mau makan.',
      'Latihan: Coba bikin satu kalimat pakai xiang?',
    ]);
  });

  test('Guru display text normalizes markdown tables and loose labels', () {
    final text = formatTutorReplyForDisplay(
      '''
| Ringkas | 喜欢 berarti suka. |
| --- | --- |
Contoh 我喜欢吃饭。
Catatan Jangan campur terlalu banyak kata baru.
Latihan Coba tulis satu kalimat.
''',
      track: 'traditional',
      primary: 'traditional',
    );

    expect(text.split('\n'), [
      'Ringkas: 喜歡 berarti suka.',
      'Contoh: 我喜歡吃飯。',
      'Catatan: Jangan campur terlalu banyak kata baru.',
      'Latihan: Coba tulis satu kalimat.',
    ]);
  });

  test('App display uses traditional primary when track is both', () {
    final c = AppController()
      ..track = 'both'
      ..primary = 'traditional';

    final text = c.displayTutorText('Ringkas: 我喜欢这本书，也想吃饭。');

    expect(text, contains('喜歡這本書'));
    expect(text, contains('吃飯'));
    expect(text, isNot(contains('喜欢')));
    expect(text, isNot(contains('饭')));
  });

  test('Belajar idiom tries LLM fallback without requiring sign-in', () async {
    final llm = _FakeLlmService();
    final c = AppController(llm: llm)
      ..track = 'both'
      ..primary = 'traditional';
    await c.idiomBank.load();
    expect(c.idiomBank.count, greaterThan(0));

    await c.learnIdiomWithGuru();

    expect(llm.called, isTrue);
    expect(llm.track, 'traditional');
    expect(c.tutorTyping, isFalse);
    expect(c.messages.last.who, 't');
    expect(c.messages.last.text, contains('\u559c\u6b61'));
    expect(c.messages.last.text, contains('\u98ef'));
  });
}

class _FakeLlmService extends LlmService {
  bool called = false;
  String? track;

  @override
  Future<String?> chat(
    List<Map<String, String>> messages, {
    required String track,
    String level = 'HSK 1-2',
    String? systemOverride,
    double temperature = 0.8,
    int maxTokens = 800,
  }) async {
    called = true;
    this.track = track;
    return 'Ringkas: \u6211\u559c\u6b22\u5403\u996d\u3002';
  }
}
