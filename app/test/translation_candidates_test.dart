import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/services/translation_service.dart';

void main() {
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
}
