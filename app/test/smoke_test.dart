import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zhongwen_shu/config.dart';
import 'package:zhongwen_shu/main.dart';

/// End-to-end widget smoke test. Disables Supabase so tests run in
/// predictable offline/guest mode regardless of backend status.
void main() {
  setUp(() {
    zwsSupabaseReady = false; // force offline guest mode for tests
  });

  testWidgets('app boots, onboards, navigates all tabs and a review flow', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: ZwsApp()));
    // Wait for app to load onboarding
    for (var i = 0; i < 40 && find.text('Masuk').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Onboarding visible
    expect(find.text('中文书'), findsOneWidget);
    expect(find.text('Masuk'), findsOneWidget);

    // Enter the app
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    // Beranda is shown
    expect(find.text('Rapor berjalan'.toUpperCase()), findsOneWidget);

    // Visit each tab
    for (final label in ['Belajar', 'Chat', 'Translate', 'Profil', 'Beranda']) {
      await tester.tap(find.text(label).first);
      await tester.pumpAndSettle();
    }

    // Translate
    await tester.tap(find.text('Translate').first);
    await tester.pumpAndSettle();
    expect(find.text('Terjemah'), findsOneWidget);

    // Chat -> Voice
    await tester.tap(find.text('Chat').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Suara & Nada'));
    await tester.pumpAndSettle();
    expect(find.text('Tuner nada'.toUpperCase()), findsOneWidget);

    // Belajar -> deck -> review -> rate
    await tester.tap(find.text('Belajar').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sapaan & Sopan Santun'));
    await tester.pumpAndSettle();
    expect(find.text('Review'), findsWidgets);
    await tester.tap(find.text('halo').first);
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (w) => w is SelectableText && w.data == 'halo / apa kabar',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();
    expect(find.text('Benar'), findsOneWidget);
    await tester.tap(find.text('Benar'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
