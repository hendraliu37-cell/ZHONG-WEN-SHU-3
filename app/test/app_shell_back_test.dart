import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhongwen_shu/app_shell.dart';
import 'package:zhongwen_shu/models/room.dart';
import 'package:zhongwen_shu/models/vocab.dart';
import 'package:zhongwen_shu/state/app_controller.dart';
import 'package:zhongwen_shu/theme/tokens.dart';
import 'package:zhongwen_shu/theme/zws_theme.dart';
import 'package:zhongwen_shu/widgets/ico.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('leaderboard overlay back button closes the overlay', (
    tester,
  ) async {
    final c = AppController()..leaderOpen = true;

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(
          home: Scaffold(body: AppShell(controller: c)),
        ),
      ),
    );

    expect(c.leaderOpen, isTrue);
    await tester.tap(find.byIcon(ZwsIcons.back).first);
    await tester.pumpAndSettle();

    expect(c.leaderOpen, isFalse);
  });

  testWidgets('group chat back button returns to room list', (tester) async {
    final c = _SignedInAppController()
      ..tab = 'chat'
      ..chatTab = 'grup'
      ..currentRoom = const Room(
        id: 'room-1',
        code: 'ZWS-23456',
        name: 'Kelas Malam',
      );

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(
          home: Scaffold(body: AppShell(controller: c)),
        ),
      ),
    );

    expect(c.currentRoom, isNotNull);
    await tester.tap(find.byIcon(ZwsIcons.back));
    await tester.pumpAndSettle();

    expect(c.currentRoom, isNull);
  });

  testWidgets('system back confirms while final exam is in progress', (
    tester,
  ) async {
    final c = AppController()
      ..sub = 'ujian_akhir'
      ..ujianAkhirInProgress = true;
    c.cards[1] = const VocabEntry(
      simplified: '吃',
      traditional: '吃',
      pinyin: 'chi1',
      meaning: 'makan',
      tone: 1,
    );

    await tester.pumpWidget(
      ZwsTheme(
        tokens: ZwsTokens.light,
        child: MaterialApp(
          home: Scaffold(body: AppShell(controller: c)),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Keluar dari ujian?'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(c.sub, 'ujian_akhir');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keluar'));
    await tester.pumpAndSettle();
    expect(c.sub, isNull);
  });
}

class _SignedInAppController extends AppController {
  @override
  bool get signedIn => true;

  @override
  String? get authUid => 'user-1';
}
