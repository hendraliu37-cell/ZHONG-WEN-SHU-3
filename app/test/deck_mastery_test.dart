import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhongwen_shu/models/vocab.dart';
import 'package:zhongwen_shu/state/app_controller.dart';

VocabEntry _vocab(int i) => VocabEntry(
  simplified: '字$i',
  traditional: '字$i',
  pinyin: 'zi$i',
  meaning: 'arti $i',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const recordChannel = MethodChannel('com.llfbandit.record/messages');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          recordChannel,
          (MethodCall call) async => null,
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(recordChannel, null);
  });

  test('deck test count is capped by the active deck size', () {
    final c = AppController();
    final ids = <int>[];
    for (var i = 0; i < 15; i++) {
      c.cards[i] = _vocab(i);
      ids.add(i);
    }

    c.qCount = 200;
    c.goTestPick(base: ids);

    expect(c.currentQuestionMax, 15);
    expect(c.qCount, 15);
    c.incCount();
    expect(c.qCount, 15);
    c.decCount();
    expect(c.qCount, 10);
    expect(c.makeSession(ids, 200).length, 15);
  });

  test('multiple-choice deck tests update SRS mastery', () {
    final c = AppController();
    final ids = <int>[];
    for (var i = 0; i < 5; i++) {
      c.cards[i] = _vocab(i);
      ids.add(i);
    }

    c.goTestPick(base: ids);
    c.qCount = 5;
    c.startMc();

    final first = c.currentQuiz!;
    c.pickQuiz(first.correct);

    final state = c.srs[first.cardId];
    expect(state, isNotNull);
    expect(state!.reps, 1);
    expect(state.isNew, isFalse);
    expect(state.mastery, greaterThan(0));
  });

  test('unfinished multiple-choice test can be saved and resumed', () {
    final c = AppController();
    final ids = <int>[];
    for (var i = 0; i < 6; i++) {
      c.cards[i] = _vocab(i);
      ids.add(i);
    }

    c.goTestPick(base: ids);
    c.qCount = 6;
    c.startMc();
    final first = c.currentQuiz!;
    c.pickQuiz(first.correct);
    c.nextQuiz();
    c.abandonActiveTestToHistory();

    final saved = c.testHistory.first;
    expect(saved.completed, isFalse);
    expect(saved.index, 1);
    expect(saved.score, 1);

    c.closeSub();
    c.resumeTestHistory(saved);
    expect(c.sub, 'quiz');
    expect(c.quizIdx, 1);
    expect(c.quizScore, 1);
    expect(c.sessionCards.length, 6);
  });

  test('final exam answers update SRS mastery', () {
    final c = AppController();
    c.cards[0] = _vocab(0);

    c.recordUjianAkhirAnswer(0, true);

    final state = c.srs[0];
    expect(state, isNotNull);
    expect(state!.reps, 1);
    expect(state.isNew, isFalse);
    expect(state.mastery, greaterThan(0));
  });
}
