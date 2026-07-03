import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/config.dart';
import 'package:zhongwen_shu/services/llm_service.dart';

void main() {
  setUp(() {
    zwsSupabaseReady = false;
  });

  tearDown(() {
    zwsSupabaseReady = false;
  });

  test('offline mode falls back without surfacing missing API key', () async {
    final llm = LlmService();

    final reply = await llm.chat([
      {'role': 'user', 'content': 'halo guru'},
    ], track: 'simplified');

    expect(reply, isNull);
    expect(llm.lastError, isNull);
  });

  test('OpenModel text parser accepts content block lists', () {
    final text = parseOpenModelTextForTest({
      'content': [
        {'type': 'text', 'text': 'Ringkas: '},
        {'type': 'text', 'text': '你好 = halo'},
      ],
    });

    expect(text, 'Ringkas: 你好 = halo');
  });

  test('OpenAI-compatible parser accepts content block lists', () {
    final text = parseOpenAiChatTextForTest({
      'choices': [
        {
          'message': {
            'content': [
              {'type': 'text', 'text': 'Contoh: '},
              {'content': '我喜欢中文。'},
            ],
          },
        },
      ],
    });

    expect(text, 'Contoh: 我喜欢中文。');
  });
}
