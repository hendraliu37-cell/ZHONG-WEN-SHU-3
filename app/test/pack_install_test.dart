import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zhongwen_shu/config.dart';
import 'package:zhongwen_shu/main.dart';

/// Pack-install E2E. Kept in its own file so it runs in a fresh test isolate:
/// `rootBundle` asset loading (the pack manifest + pack data) is only reliable
/// for the first widget test in an isolate — a later test in the same file
/// hangs on the torn-down asset channel. Isolation per file avoids that.
void main() {
  setUp(() {
    zwsSupabaseReady = false;
  });

  testWidgets('downloadable HSK pack installs into the library',
      (tester) async {
    // Stub the record MethodChannel so AudioRecorder constructor doesn't throw
    // MissingPluginException in the test environment.
    final recordChannel = const MethodChannel('com.llfbandit.record/messages');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      recordChannel,
      (MethodCall call) async {
        // Return null (as void) for every call — the test never uses recording.
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(recordChannel, null);
    });

    // Tall, narrow surface (mobile layout) so the whole Belajar screen —
    // including the packs section — is visible without scrolling.
    await tester.binding.setSurfaceSize(const Size(460, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: ZwsApp()));
    // Wait for async init (load packs + persistence) to complete.
    for (var i = 0; i < 60 && find.text('Masuk').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Belajar').first);
    await tester.pumpAndSettle();

    // install the first available pack
    expect(find.text('Unduh'), findsWidgets);
    await tester.tap(find.text('Unduh').first);
    // Let async I/O (rootBundle.loadString) complete, then pump frames.
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 1)));
    for (var i = 0; i < 120; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.text('Terunduh').evaluate().isNotEmpty) break;
    }

    // at least one pack now shows as downloaded
    expect(find.text('Terunduh'), findsWidgets);
  });
}
