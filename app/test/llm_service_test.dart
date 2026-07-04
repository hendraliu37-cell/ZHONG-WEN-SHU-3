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

  test('OpenModel text parser accepts responses-style output text', () {
    expect(
      parseOpenModelTextForTest({'output_text': ' Ringkas: 你好 = halo '}),
      'Ringkas: 你好 = halo',
    );

    final nested = parseOpenModelTextForTest({
      'output': [
        {
          'content': [
            {'type': 'output_text', 'text': 'Contoh: '},
            {'type': 'output_text', 'text': '我喜欢中文。'},
          ],
        },
      ],
    });

    expect(nested, 'Contoh: 我喜欢中文。');
  });

  test('OpenModel text parser accepts single object content blocks', () {
    expect(
      parseOpenModelTextForTest({
        'content': {'type': 'text', 'text': 'Ringkas: \u4f60\u597d = halo'},
      }),
      'Ringkas: \u4f60\u597d = halo',
    );

    expect(
      parseOpenModelTextForTest({
        'output': {
          'content': [
            {'type': 'output_text', 'text': 'Contoh: '},
            {
              'type': 'output_text',
              'text': '\u6211\u559c\u6b22\u4e2d\u6587\u3002',
            },
          ],
        },
      }),
      'Contoh: \u6211\u559c\u6b22\u4e2d\u6587\u3002',
    );
  });

  test('LLM proxy parser accepts raw JSON string responses', () {
    expect(
      parseLlmProxyReplyForTest('{"reply":"  Ringkas: 你好 = halo  "}'),
      'Ringkas: 你好 = halo',
    );
    expect(parseLlmProxyReplyForTest('not-json'), isNull);
    expect(parseLlmProxyReplyForTest({'reply': '   '}), isNull);
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

  test('direct fallback distinguishes bad model from bad API key', () {
    expect(
      looksLikeModelSelectionErrorForTest(
        '{"error":{"type":"ModelError","message":"model not found"}}',
      ),
      isTrue,
    );
    expect(
      looksLikeModelSelectionErrorForTest(
        '{"error":"invalid model: deepseek-v4-flash"}',
      ),
      isTrue,
    );
    expect(
      looksLikeModelSelectionErrorForTest(
        '{"error":{"type":"AuthError","message":"invalid api key"}}',
      ),
      isFalse,
    );
  });
}
