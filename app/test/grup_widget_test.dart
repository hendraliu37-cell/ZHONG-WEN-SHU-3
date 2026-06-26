import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zhongwen_shu/config.dart';
import 'package:zhongwen_shu/main.dart';

/// In guest mode (no backend, as in tests) the Grup tab must render its
/// sign-in empty state without throwing — the realtime room UI requires an
/// account. Guards the graceful-degradation contract.
void main() {
  setUp(() {
    zwsSupabaseReady = false;
  });

  testWidgets('Grup tab shows the sign-in empty state in guest mode',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: ZwsApp()));
    for (var i = 0; i < 40 && find.text('Masuk').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grup'));
    await tester.pumpAndSettle();

    expect(find.text('Masuk untuk pakai grup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
