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
}
