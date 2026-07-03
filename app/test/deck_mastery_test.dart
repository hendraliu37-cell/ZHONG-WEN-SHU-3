import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhongwen_shu/models/deck.dart';
import 'package:zhongwen_shu/models/room.dart';
import 'package:zhongwen_shu/models/vocab.dart';
import 'package:zhongwen_shu/services/room_service.dart';
import 'package:zhongwen_shu/srs/fsrs.dart';
import 'package:zhongwen_shu/state/app_controller.dart';

VocabEntry _vocab(int i) => VocabEntry(
  simplified: '字$i',
  traditional: '字$i',
  pinyin: 'zi$i',
  meaning: 'arti $i',
  tone: (i % 4) + 1,
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

  test('both-track voice and primary Hanzi follow traditional primary', () {
    final c = AppController()
      ..track = 'both'
      ..primary = 'traditional';
    final card = VocabEntry(
      simplified: '\u7231',
      traditional: '\u611b',
      pinyin: 'ai4',
      meaning: 'cinta',
      tone: 4,
    );

    expect(c.usesTraditionalHanzi, isTrue);
    expect(c.primaryHanzi(card), '\u611b');
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

  test('empty deck test picker does not borrow cards from other decks', () {
    final c = AppController();
    c.cards[7] = _vocab(7);
    c.decks.add(Deck(id: 'empty', displayIdx: '01', name: 'Deck kosong'));

    c.openDeckById('empty');
    c.deckTest();

    expect(c.currentQuestionMax, 0);
    expect(c.qCount, 0);
    expect(c.questionLimitLabel, contains('Belum ada kartu'));

    c.startMc();
    expect(c.sub, 'testpick');
    expect(c.sessionCards, isEmpty);
    expect(c.testHistory, isEmpty);

    c.startSelf();
    expect(c.sub, 'testpick');
    expect(c.testHistory, isEmpty);

    c.startSpell();
    expect(c.sub, 'testpick');
    expect(c.testHistory, isEmpty);
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

  test('multiple-choice finish rewards only once on repeated next taps', () {
    final c = AppController();
    for (var i = 0; i < 4; i++) {
      c.cards[i] = _vocab(i);
    }

    c.goTestPick(base: [0, 1, 2, 3]);
    c.qCount = 1;
    c.startMc();
    final q = c.currentQuiz!;
    c.pickQuiz(q.correct);
    c.nextQuiz();
    final xpAfterFinish = c.xp;
    final idxAfterFinish = c.quizIdx;

    c.nextQuiz();

    expect(c.xp, xpAfterFinish);
    expect(c.quizIdx, idxAfterFinish);
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

  test('controller back saves unfinished active test history', () {
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

    expect(c.handleBack(), isTrue);
    final saved = c.testHistory.first;
    expect(saved.completed, isFalse);
    expect(saved.index, 1);
    expect(saved.score, 1);

    c.resumeTestHistory(saved);
    expect(c.sub, 'quiz');
    expect(c.quizIdx, 1);
    expect(c.quizScore, 1);
  });

  test('completed test history cannot be resumed into an invalid session', () {
    final c = AppController();
    for (var i = 0; i < 2; i++) {
      c.cards[i] = _vocab(i);
    }

    final completed = TestHistoryItem(
      id: 'done',
      mode: 'mc',
      title: 'Tes selesai',
      direction: 'zh2id',
      cardIds: const [0, 1],
      index: 2,
      score: 2,
      completed: true,
      startedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final exhausted = TestHistoryItem(
      id: 'exhausted',
      mode: 'mc',
      title: 'Tes lama',
      direction: 'zh2id',
      cardIds: const [0, 1],
      index: 2,
      score: 1,
      completed: false,
      startedAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    c.resumeTestHistory(completed);
    expect(c.sub, isNull);
    expect(c.sessionCards, isEmpty);

    c.resumeTestHistory(exhausted);
    expect(c.sub, isNull);
    expect(c.sessionCards, isEmpty);
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

  test('tone game answers update SRS mastery', () {
    final c = AppController();
    for (var i = 0; i < 4; i++) {
      c.cards[i] = _vocab(i);
    }

    c.qCount = 1;
    c.startTone();
    final id = c.sessionCards.first;

    c.pickTone(c.card(id).tone);

    final state = c.srs[id];
    expect(state, isNotNull);
    expect(state!.reps, 1);
    expect(state.isNew, isFalse);
    expect(state.mastery, greaterThan(0));
  });

  test('tone game finish rewards only once on repeated next taps', () {
    final c = AppController();
    c.cards[0] = _vocab(0);

    c.qCount = 1;
    c.startTone();
    final id = c.sessionCards.first;
    c.pickTone(c.card(id).tone);
    c.nextTone();
    final xpAfterFinish = c.xp;
    final idxAfterFinish = c.toneIdx;

    c.nextTone();

    expect(c.xp, xpAfterFinish);
    expect(c.toneIdx, idxAfterFinish);
  });

  test('listening quiz always asks for meaning even after id to zh tests', () {
    final c = AppController();
    for (var i = 0; i < 4; i++) {
      c.cards[i] = _vocab(i);
    }

    c.toggleTestDirection();
    expect(c.testDirection, 'id2zh');

    c.goListen();
    final q = c.currentQuiz!;
    final card = c.card(q.cardId);

    expect(q.correct, card.primaryMeaning);
    expect(q.options, contains(card.primaryMeaning));
    expect(q.options, isNot(contains(c.primaryHanzi(card))));
    expect(c.testDirection, 'id2zh');
  });

  test('listening quiz finish rewards only once on repeated next taps', () {
    final c = AppController();
    c.cards[0] = _vocab(0);

    c.qCount = 1;
    c.goListen();
    final q = c.currentQuiz!;
    c.pickQuiz(q.correct);
    c.nextListen();
    final xpAfterFinish = c.xp;
    final idxAfterFinish = c.quizIdx;

    c.nextListen();

    expect(c.xp, xpAfterFinish);
    expect(c.quizIdx, idxAfterFinish);
  });

  test('spelling finish stays stable on repeated next taps', () {
    final c = AppController();
    c.cards[0] = _vocab(0);

    c.goTestPick(base: [0]);
    c.qCount = 1;
    c.startSpell();
    c.setSpellInput(c.card(0).pinyin);
    c.checkSpell();
    c.nextSpell();
    final idxAfterFinish = c.spellIdx;
    final historyAfterFinish = c.testHistory.single;

    c.nextSpell();

    expect(c.spellIdx, idxAfterFinish);
    expect(c.testHistory.single.index, historyAfterFinish.index);
    expect(c.testHistory.single.completed, isTrue);
    expect(c.testHistory.single.score, 1);
  });

  test('games stay on hub when no cards are available', () {
    final c = AppController();

    c.goGames();
    expect(c.sub, 'games');
    expect(c.qCount, 0);

    c.startTone();
    expect(c.sub, 'games');
    expect(c.sessionCards, isEmpty);

    c.startMatch();
    expect(c.sub, 'games');
    expect(c.matchPairs, isEmpty);
    expect(c.matchTiles, isEmpty);

    c.goListen();
    expect(c.sub, 'games');
    expect(c.quiz, isEmpty);

    c.startSpeed();
    expect(c.sub, 'games');
    expect(c.speed, isEmpty);
    expect(c.speedIdx, 0);
  });

  test('empty quiz and tone actions are no-ops', () {
    final c = AppController();

    expect(() => c.pickQuiz('x'), returnsNormally);
    expect(() => c.nextQuiz(), returnsNormally);
    expect(() => c.nextListen(), returnsNormally);
    expect(() => c.pickTone(1), returnsNormally);
    expect(() => c.nextTone(), returnsNormally);
    expect(() => c.checkSpell(), returnsNormally);
    expect(() => c.nextSpell(), returnsNormally);
    expect(() => c.restartSpell(), returnsNormally);

    expect(c.xp, 0);
    expect(c.quizIdx, 0);
    expect(c.toneIdx, 0);
    expect(c.spellIdx, 0);
    expect(c.testHistory, isEmpty);
  });

  test('daily tests and games use AI-focused learning cards', () {
    final c = AppController();
    for (var i = 0; i < 4; i++) {
      c.cards[i] = _vocab(i);
    }
    c.aiFocusCardIds = [2, 1];
    c.qCount = 2;

    c.goDailyTest();
    expect(c.baseCards.take(2), [2, 1]);

    c.goGames();
    expect(c.baseCards.take(2), [2, 1]);

    c.startTone();
    expect(c.sessionCards, containsAll([2, 1]));
  });

  test('daily tests prefer recent AI learning over stale deck base cards', () {
    final c = AppController();
    for (var i = 0; i < 5; i++) {
      c.cards[i] = _vocab(i);
    }
    c.baseCards = [0, 3, 4];
    c.aiFocusCardIds = [2, 1];
    c.qCount = 2;

    c.goDailyTest();

    expect(c.baseCards.take(2), [2, 1]);
    expect(c.currentQuestionMax, 5);
  });

  test(
    'deleting a deck removes only unreferenced cards from practice pool',
    () {
      final c = AppController();
      for (var i = 0; i < 3; i++) {
        c.cards[i] = _vocab(i);
        c.srs[i] = SrsState();
      }
      c.decks.addAll([
        Deck(id: 'a', displayIdx: '01', name: 'A', cardIds: [0, 1]),
        Deck(id: 'b', displayIdx: '02', name: 'B', cardIds: [1, 2]),
      ]);

      c.deleteDeck('a');

      expect(c.decks.map((d) => d.id), ['b']);
      expect(c.cards.containsKey(0), isFalse);
      expect(c.srs.containsKey(0), isFalse);
      expect(c.cards.containsKey(1), isTrue);
      expect(c.srs.containsKey(1), isTrue);
      expect(c.smartPracticeBase(), isNot(contains(0)));
      expect(c.smartPracticeBase(), containsAll([1, 2]));
    },
  );

  test('database update remaps pack test history and AI focus cards', () async {
    final raw = await rootBundle.loadString('assets/packs/hsk1.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final packCard = VocabEntry.fromJson(
      Map<String, dynamic>.from((data['cards'] as List).first as Map),
    );
    final c = AppController();
    c.cards[1] = packCard;
    c.srs[1] = SrsState(stability: 20, reps: 4, isNew: false);
    c.decks.add(
      Deck(
        id: 'pack_hsk1',
        displayIdx: '01',
        name: 'Paket HSK 1 lama',
        standard: 'hsk',
        levelTag: 'HSK 1',
        isPack: true,
        cardIds: [1],
      ),
    );
    c.installedPacks.add('hsk1');
    c.aiFocusCardIds = [1];
    c.testHistory = [
      TestHistoryItem(
        id: 'history',
        mode: 'mc',
        title: 'Tes HSK 1',
        deckId: 'pack_hsk1',
        direction: 'zh2id',
        cardIds: const [1],
        index: 0,
        score: 0,
        startedAt: DateTime(2026, 7),
        updatedAt: DateTime(2026, 7, 1, 0, 1),
      ),
    ];

    await c.syncDatabaseUpdate();

    final updatedDeck = c.decks.singleWhere((d) => d.id == 'pack_hsk1');
    final newId = updatedDeck.cardIds.first;
    expect(newId, isNot(1));
    expect(c.cards.containsKey(1), isFalse);
    expect(c.srs[newId]?.reps, 4);
    expect(c.aiFocusCardIds, [newId]);
    expect(c.testHistory.single.cardIds, [newId]);
    expect(c.testHistory.single.completed, isFalse);
  });

  test('back handler closes leaderboard and active group room', () {
    final c = AppController();

    c.leaderOpen = true;
    expect(c.handleBack(), isTrue);
    expect(c.leaderOpen, isFalse);

    c
      ..tab = 'chat'
      ..chatTab = 'grup'
      ..currentRoom = const Room(id: 'r1', code: 'ZWS-ABCDE', name: 'Kelas')
      ..roomLoading = true
      ..roomGuruBusy = true
      ..roomMsgs = [
        RoomMessage(
          id: 1,
          senderId: 'u1',
          authorName: 'A',
          body: 'halo',
          createdAt: DateTime(2026),
        ),
      ];

    expect(c.handleBack(), isTrue);
    expect(c.currentRoom, isNull);
    expect(c.roomMsgs, isEmpty);
    expect(c.roomLoading, isFalse);
    expect(c.roomGuruBusy, isFalse);
  });

  test('profile reset clears active group session state', () {
    final c = AppController()
      ..myRooms = [const Room(id: 'r1', code: 'ZWS-ABCDE', name: 'Kelas')]
      ..currentRoom = const Room(id: 'r1', code: 'ZWS-ABCDE', name: 'Kelas')
      ..roomInput = '@Guru bantu'
      ..roomOnline = 3
      ..roomLoading = true
      ..roomGuruBusy = true
      ..roomMsgs = [
        RoomMessage(
          id: 1,
          senderId: 'u1',
          authorName: 'A',
          body: 'halo',
          createdAt: DateTime(2026),
        ),
      ];

    c.resetProfileToGuestForTest();

    expect(c.profileName, 'Murid');
    expect(c.myRooms, isEmpty);
    expect(c.currentRoom, isNull);
    expect(c.roomMsgs, isEmpty);
    expect(c.roomInput, isEmpty);
    expect(c.roomOnline, 0);
    expect(c.roomLoading, isFalse);
    expect(c.roomGuruBusy, isFalse);
  });

  test('failed room send keeps draft for retry and close clears it', () async {
    final c = AppController()
      ..currentRoom = const Room(id: 'r1', code: 'ZWS-ABCDE', name: 'Kelas')
      ..profileName = 'Hendra'
      ..profileHandle = '#1234';

    c.setRoomInput('halo gagal');
    await c.sendRoom();

    expect(c.roomInput, 'halo gagal');
    expect(c.roomMsgs.last.body, roomSendFailureMessage());

    c.closeRoomChannel();
    expect(c.roomInput, isEmpty);
    expect(c.roomMsgs, isEmpty);
  });

  test('failed room send does not update AI learning focus', () async {
    final c = AppController()
      ..currentRoom = const Room(id: 'r1', code: 'ZWS-ABCDE', name: 'Kelas')
      ..profileName = 'Hendra'
      ..profileHandle = '#1234';
    c.cards[1] = _vocab(1);

    c.setRoomInput('aku mau latihan arti 1');
    await c.sendRoom();

    expect(c.roomInput, 'aku mau latihan arti 1');
    expect(c.aiFocusCardIds, isEmpty);
    expect(c.smartPracticeBase(limit: 1), [1]);
  });

  test('successful group Guru call clears local typing state', () async {
    final rooms = _SuccessfulGuruRoomService();
    final c = AppController(rooms: rooms)
      ..currentRoom = const Room(id: 'r1', code: 'ZWS-ABCDE', name: 'Kelas')
      ..profileName = 'Hendra'
      ..profileHandle = '#1234'
      ..track = 'both'
      ..primary = 'traditional';

    c.setRoomInput('@Guru bantu jelaskan');
    await c.sendRoom();

    expect(rooms.sentMessages, 1);
    expect(rooms.guruCalls, 1);
    expect(rooms.track, 'traditional');
    expect(c.roomGuruBusy, isFalse);
    expect(c.roomInput, isEmpty);
  });

  test(
    'delayed match feedback does not notify after controller dispose',
    () async {
      final c = AppController();
      for (var i = 0; i < 4; i++) {
        c.cards[i] = _vocab(i);
      }

      c.startMatch();
      final first = 0;
      final second = c.matchTiles.indexWhere((tile) {
        final selected = c.matchTiles[first];
        return tile.pid != selected.pid;
      });
      expect(second, isNonNegative);

      c.matchTap(first);
      c.matchTap(second);
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 800));
    },
  );
}

class _SuccessfulGuruRoomService extends RoomService {
  int sentMessages = 0;
  int guruCalls = 0;
  String? track;

  @override
  Future<bool> sendMessage(
    String roomId, {
    required String body,
    required String authorName,
    required String authorHandle,
  }) async {
    sentMessages += 1;
    return true;
  }

  @override
  Future<String?> callGuru(String roomId, {String track = 'simplified'}) async {
    guruCalls += 1;
    this.track = track;
    return null;
  }
}
