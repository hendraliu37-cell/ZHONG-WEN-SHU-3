import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/state/app_controller.dart';

void main() {
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
}
