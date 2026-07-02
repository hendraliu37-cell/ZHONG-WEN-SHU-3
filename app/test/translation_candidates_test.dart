import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/services/llm_service.dart';
import 'package:zhongwen_shu/services/translation_service.dart';

void main() {
  test(
    'AI translate falls back to direct LLM JSON when proxy is unavailable',
    () async {
      final service = TranslationService(
        llm: _FakeLlmService('''```json
{"translation":"你好","pinyin":"ni3 hao3","tokens":[{"hanzi":"你好","pinyin":"ni3 hao3","meaning":"halo","hsk":1}]}
```'''),
      );

      final result = await service.translate('halo', from: 'id', to: 'zh');

      expect(result, isNotNull);
      expect(result!.translation, '你好');
      expect(result.pinyin, 'ni3 hao3');
      expect(result.tokens.single.hanzi, '你好');
      expect(result.tokens.single.meaning, 'halo');
      expect(result.tokens.single.hsk, 1);
      expect(service.lastError, isNull);
    },
  );

  test(
    'Indonesian halo prefers the common greeting before phone hello',
    () async {
      final service = TranslationService();

      final result = await service.translate(
        'halo',
        from: 'id',
        to: 'zh',
        engine: 'dict',
      );

      expect(result, isNotNull);
      expect(result!.translation, '你好');
      expect(result.pinyin, 'nǐ hǎo');
      expect(result.alternatives.map((t) => t.hanzi), contains('喂'));
    },
  );

  test(
    'Indonesian makan prefers modern common 吃 before formal variants',
    () async {
      final service = TranslationService();

      final result = await service.translate(
        'makan',
        from: 'id',
        to: 'zh',
        engine: 'dict',
        track: 'traditional',
      );

      expect(result, isNotNull);
      expect(result!.translation, '吃');
      expect(result.pinyin, 'chī');
      expect(result.alternatives.map((t) => t.hanzi), contains('吃飯'));
      expect(result.alternatives.map((t) => t.hanzi), isNot(contains('吃饭')));
      expect(result.alternatives.map((t) => t.hanzi), isNot(contains('喫')));
    },
  );

  test(
    'dictionary fallback normalizes obsolete traditional eating variant',
    () async {
      final service = TranslationService();
      service.loadFromCards([
        {'s': '好吃', 't': '好喫', 'py': 'hǎochī', 'm': 'enak', 'hsk': 1},
        {'s': '美味', 't': '美味', 'py': 'měiwèi', 'm': 'enak', 'hsk': 4},
      ]);

      final result = await service.translate(
        'enak',
        from: 'id',
        to: 'zh',
        engine: 'dict',
        track: 'traditional',
      );

      expect(result, isNotNull);
      expect(result!.translation, '好吃');
      expect(result.alternatives.map((t) => t.hanzi), contains('美味'));
    },
  );

  test(
    'Indonesian phrase fallback keeps following words in the translation',
    () async {
      final service = TranslationService();

      final result = await service.translate(
        'saya suka makan',
        from: 'id',
        to: 'zh',
        engine: 'dict',
      );

      expect(result, isNotNull);
      expect(result!.translation, '我喜欢吃');
      expect(result.pinyin, 'wǒ xǐhuān chī');
      expect(result.tokens.map((t) => t.meaning), ['saya suka', 'makan']);
    },
  );

  test('Indonesian phrase fallback ignores surrounding punctuation', () async {
    final service = TranslationService();

    final greeting = await service.translate(
      'apa kabar?',
      from: 'id',
      to: 'zh',
      engine: 'dict',
    );
    final sentence = await service.translate(
      'saya suka, makan.',
      from: 'id',
      to: 'zh',
      engine: 'dict',
    );

    expect(greeting, isNotNull);
    expect(greeting!.translation, '你好吗');
    expect(sentence, isNotNull);
    expect(sentence!.translation, '我喜欢吃');
  });

  test('Indonesian sentence fallback respects traditional track', () async {
    final service = TranslationService();

    final result = await service.translate(
      'saya suka makanan',
      from: 'id',
      to: 'zh',
      engine: 'dict',
      track: 'traditional',
    );

    expect(result, isNotNull);
    expect(result!.translation, '我喜歡食物');
    expect(result.pinyin, 'wǒ xǐhuān shíwù');
  });

  test('Indonesian fallback rejects unknown-only text', () async {
    final service = TranslationService();

    final result = await service.translate(
      'foobar bazqux',
      from: 'id',
      to: 'zh',
      engine: 'dict',
    );

    expect(result, isNull);
    expect(service.lastError, contains('kamus offline'));
  });

  test('Indonesian fallback keeps partial known words', () async {
    final service = TranslationService();

    final result = await service.translate(
      'makan foobar',
      from: 'id',
      to: 'zh',
      engine: 'dict',
    );

    expect(result, isNotNull);
    expect(result!.translation, startsWith('\u5403'));
    expect(result.tokens.first.meaning, 'makan');
  });

  test('Chinese fallback ignores punctuation and latin runs', () async {
    final service = TranslationService();
    service.loadFromCards([
      {'s': '我', 't': '我', 'py': 'wǒ', 'm': 'saya', 'hsk': 1},
      {'s': '喜欢', 't': '喜歡', 'py': 'xǐhuān', 'm': 'suka', 'hsk': 1},
      {
        's': '中文',
        't': '中文',
        'py': 'zhōngwén',
        'm': 'bahasa Mandarin',
        'hsk': 1,
      },
    ]);

    final result = await service.translate(
      '我, 喜欢 ok。中文!',
      from: 'zh',
      to: 'id',
      engine: 'dict',
    );

    expect(result, isNotNull);
    expect(result!.translation, 'saya suka bahasa Mandarin');
    expect(result.tokens.map((t) => t.hanzi), ['我', '喜欢', '中文']);
  });
  test(
    'Chinese fallback rejects latin-only input instead of blank success',
    () async {
      final service = TranslationService();

      final result = await service.translate(
        'ok, hello!',
        from: 'zh',
        to: 'id',
        engine: 'dict',
      );

      expect(result, isNull);
      expect(service.lastError, contains('Hanzi'));
    },
  );
}

class _FakeLlmService extends LlmService {
  final String? reply;
  _FakeLlmService(this.reply);

  @override
  Future<String?> chat(
    List<Map<String, String>> messages, {
    required String track,
    String level = 'HSK 1-2',
    String? systemOverride,
    double temperature = 0.8,
    int maxTokens = 800,
  }) async {
    expect(level, 'translation');
    expect(systemOverride, isNotNull);
    return reply;
  }
}
