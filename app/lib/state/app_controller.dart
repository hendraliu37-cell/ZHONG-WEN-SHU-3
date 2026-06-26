import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthState, AuthChangeEvent, RealtimeChannel;
import 'package:record/record.dart' show InputDevice;

import '../models/vocab.dart';
import '../models/deck.dart';
import '../models/room.dart';
import '../models/curriculum.dart';
import '../srs/fsrs.dart';
import '../srs/tone_match.dart';
import '../services/speech.dart';
import '../services/auth_service.dart';
import '../services/llm_service.dart';
import '../services/pitch_service.dart';
import '../services/translation_service.dart';
import '../services/deck_io_service.dart';
import '../services/dictionary_service.dart';
import '../services/idiom_bank.dart';
import '../services/curriculum_service.dart';
import '../services/stt_service.dart';
import '../services/ocr_service.dart';
import '../services/room_service.dart';
import '../data/seed.dart';
import '../data/leaderboard.dart';
import 'persistence.dart';

/// One MC/Listening question.
class QuizItem {
  final int cardId;
  final String correct;
  final List<String> options;
  QuizItem({
    required this.cardId,
    required this.correct,
    required this.options,
  });
}

/// Chat / room message.
class ChatMsg {
  final String who; // 't' tutor | 'me' | 'o' other
  final String? name;
  final String text;
  ChatMsg(this.who, this.text, {this.name});

  factory ChatMsg.fromJson(Map<String, dynamic> j) => ChatMsg(
    (j['who'] as String?) == 'me' ? 'me' : 't',
    (j['text'] as String?) ?? '',
    name: j['name'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'who': who,
    'text': text,
    if (name != null) 'name': name,
  };
}

class TranslateHistoryItem {
  final String source;
  final String translation;
  final String from;
  final String to;
  final String engine;
  final String? pinyin;
  final DateTime at;

  const TranslateHistoryItem({
    required this.source,
    required this.translation,
    required this.from,
    required this.to,
    required this.engine,
    this.pinyin,
    required this.at,
  });

  factory TranslateHistoryItem.fromJson(Map<String, dynamic> j) =>
      TranslateHistoryItem(
        source: (j['source'] as String?) ?? '',
        translation: (j['translation'] as String?) ?? '',
        from: (j['from'] as String?) ?? 'zh',
        to: (j['to'] as String?) ?? 'id',
        engine: (j['engine'] as String?) ?? 'dict',
        pinyin: j['pinyin'] as String?,
        at: DateTime.tryParse((j['at'] as String?) ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
    'source': source,
    'translation': translation,
    'from': from,
    'to': to,
    'engine': engine,
    if (pinyin != null && pinyin!.isNotEmpty) 'pinyin': pinyin,
    'at': at.toIso8601String(),
  };
}

/// A downloadable pack from the asset manifest.
class PackInfo {
  final String id;
  final String name;
  final String meta;
  final String standard; // 'hsk' | 'tocfl'
  final String levelTag;
  final String asset; // path to the pack json
  PackInfo({
    required this.id,
    required this.name,
    required this.meta,
    required this.standard,
    required this.levelTag,
    required this.asset,
  });
  factory PackInfo.fromJson(Map<String, dynamic> j) => PackInfo(
    id: j['id'] as String,
    name: j['name'] as String,
    meta: j['meta'] as String,
    standard: j['standard'] as String,
    levelTag: (j['levelTag'] ?? '') as String,
    asset: j['asset'] as String,
  );
}

/// Mengembalikan salinan [history] di mana pesan user TERAKHIR diperkaya blok
/// konteks bank idiom bila ada idiom terdeteksi. Murni & teruji (no I/O).
List<Map<String, String>> buildGroundedHistory(
  List<Map<String, String>> history,
  IdiomBank bank,
) {
  if (history.isEmpty) return history;
  final lastUser = history.lastIndexWhere((m) => m['role'] == 'user');
  if (lastUser < 0) return history;
  final content = history[lastUser]['content'] ?? '';
  final hits = bank.detect(content);
  if (hits.isEmpty) return history;
  final block = bank.contextBlock(hits);
  final copy = history.map((m) => Map<String, String>.from(m)).toList();
  copy[lastUser]['content'] =
      '$content\n\n[Bank idiom — jelaskan dari data ini, jangan mengarang:\n$block]';
  return copy;
}

/// The whole-app controller. Mirrors the prototype's single component: it owns
/// all state and every action, and notifies listeners on change (the UI
/// re-renders wholesale, exactly like the prototype's setState).
class AppController extends ChangeNotifier {
  AppController({Persistence? store, SpeechService? speech})
    : _store = store ?? Persistence(),
      speech = speech ?? SpeechService();

  final Persistence _store;
  final SpeechService speech;
  final math.Random rng = math.Random();
  final _fsrs = const Fsrs();

  // ---- auth ----
  final AuthService auth = AuthService();
  final LlmService llm = LlmService();
  final TranslationService translation = TranslationService();
  final DeckIoService deckIo = DeckIoService();
  final DictionaryService dict = DictionaryService();
  final IdiomBank idiomBank = IdiomBank();
  final CurriculumService curriculum = CurriculumService();
  final SttService _stt = SttService();
  final OcrService _ocr = OcrService();
  bool tutorTyping = false;
  List<LeaderRow> leaderRows = [];
  StreamSubscription<AuthState>? _authSub;
  bool authBusy = false;
  String? authError;
  bool get authEnabled => auth.enabled;
  bool get signedIn => auth.signedIn;
  bool databaseSyncBusy = false;
  String databaseSyncMsg = '';

  /// The auth user id (uuid) — matches `sender_id`/`owner` in the rooms tables.
  /// Distinct from [profileId], which is the public "#1234" display id.
  String? get authUid => auth.uid;

  bool ready = false;

  // ---- persistent app config ----
  bool onboarded = false;
  String themeMode = 'system'; // 'system' | 'light' | 'dark'
  String track = 'both'; // 'simplified' | 'traditional' | 'both'
  String primary = 'simplified'; // when track == both
  bool zhuyin = true;

  // ---- profile ----
  String profileName = 'Murid';
  String profileHandle = '';
  String profileId = '';
  String? avatarUrl;
  int xp = 0;
  int streak = 0;
  int lastTestPct = 0;
  int lastUjianAkhirPct = 0;
  String? lastActiveDate; // 'yyyy-mm-dd' of the last active day (drives streak)

  // ---- card store ----
  final Map<int, VocabEntry> cards = {};
  final List<Deck> decks = [];
  final Map<int, SrsState> srs = {};
  int _nextId = 0;
  final Set<String> installedPacks = {};

  // ---- pack catalog ----
  final List<PackInfo> packCatalog = [];

  // ---- navigation ----
  String tab = 'beranda';
  String? sub; // overlay id
  String? _deckCtx; // remembered open-deck id for back nav
  bool leaderOpen = false;
  String chatTab = 'ai'; // 'ai' (Guru) | 'grup' — within the merged Chat tab
  String guruTab = 'chat';

  // ---- curriculum / daily material ----
  DailyMaterial? dailyMaterial;
  bool curriculumLoading = false;

  // ---- shared session ----
  int qCount = 20;
  List<int> baseCards = [];
  List<int> sessionCards = [];
  String? openDeckId;
  bool adding = false;
  String deckIoMsg = '';
  String testDirection =
      'zh2id'; // 'zh2id' = show hanzi→answer meaning, 'id2zh' = show meaning→answer hanzi

  // ---- review / self-check ----
  String reviewMode = 'srs'; // 'srs' | 'self'
  int reviewIdx = 0;
  bool flipped = false;
  int reviewScore = 0;

  // ---- mc / listen ----
  List<QuizItem> _quiz = [];
  int quizIdx = 0;
  int quizScore = 0;
  String? quizPicked;

  // ---- spelling ----
  int spellIdx = 0;
  String spellInput = '';
  bool spellChecked = false;
  bool spellCorrect = false;
  int spellScore = 0;

  // ---- tone game ----
  int toneIdx = 0;
  int? tonePicked;
  int toneScore = 0;

  // ---- match game ----
  List<int> _matchPairs = [];
  List<({int pid, String kind, String label})> _matchTiles = [];
  List<int> matchMatched = [];
  int? matchSel;
  List<int> matchWrong = [];
  int matchMoves = 0;

  // ---- speed game ----
  List<QuizItem> _speed = [];
  int speedIdx = 0;
  int speedScore = 0;
  int speedLeft = 45;
  Timer? _speedTimer;

  // ---- write ----
  int writeDeck = 0;
  String writeMsg = '';

  // ---- tuner / mic ----
  int tunerTone = 2;
  bool recording = false;
  final PitchService _pitch = PitchService();
  List<double> pitchTrace =
      []; // semitones of the current syllable, newest last
  double? currentHz;
  double tunerMatch = 0; // 0..1 live tone-shape match for the selected tone

  // ---- chat ----
  String chatInput = '';
  List<ChatMsg> messages = [];
  static const int _maxChatHistory = 120;

  // ---- grup (realtime rooms) ----
  final RoomService rooms = RoomService();
  List<Room> myRooms = [];
  Room? currentRoom;
  List<RoomMessage> roomMsgs = [];
  int roomOnline = 0;
  bool roomGuruBusy = false;
  String roomInput = '';
  RealtimeChannel? _roomChannel;
  bool roomLoading = false;

  // ===========================================================================
  // INIT / PERSISTENCE
  // ===========================================================================

  Future<void> init() async {
    try {
      await _doInit().timeout(const Duration(seconds: 4));
    } on TimeoutException catch (_) {
      // safety: fall through to ready mark below
    } catch (_) {}
    // Safety: always mark ready
    if (!ready) {
      _seedFresh();
      messages = [ChatMsg('t', 'Selamat datang di 中文书!')];
      ready = true;
      notifyListeners();
    }
  }

  Future<void> _doInit() async {
    try {
      await _loadPackCatalog().timeout(const Duration(seconds: 2));
    } catch (_) {}
    // ... rest unchanged

    idiomBank.load();
    fetchDailyMaterial();
    _loadTranslationDict();

    try {
      final saved = await _store.load().timeout(const Duration(seconds: 2));
      if (saved == null) {
        _seedFresh();
      } else {
        _restore(saved);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[init] restore failed: $e');
      cards.clear();
      decks.clear();
      srs.clear();
      _nextId = 0;
      installedPacks.clear();
      _seedFresh();
    }

    if (messages.isEmpty) {
      messages = [
        ChatMsg(
          't',
          'Selamat datang di 中文书! Aku Guru-mu. Mau mulai dari mana — kosakata, latihan nada, atau langsung ngobrol pakai Mandarin? Ketik apa saja, nanti kubantu.',
        ),
      ];
    }

    // Auth: only if Supabase is ready. Do NOT block on network calls.
    if (auth.enabled) {
      _authSub = auth.onAuthChange.listen(_onAuthChange);
      // Try to load profile but don't await — let it complete in background
      if (auth.signedIn) _loadProfile();
    } else {
      _registerAttendanceToday();
    }

    ready = true;
    notifyListeners();
  }

  void _onAuthChange(AuthState s) {
    switch (s.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.userUpdated:
        _loadProfile();
        break;
      case AuthChangeEvent.signedOut:
        _resetProfileToGuest();
        notifyListeners();
        break;
      default:
        break;
    }
  }

  Future<void> _loadTranslationDict() async {
    // Load the full combined dictionary (13K+ entries) from assets.
    await translation.loadAsset();
  }

  Future<void> fetchDailyMaterial() async {
    if (curriculumLoading) return;
    curriculumLoading = true;
    notifyListeners();
    final mat = await curriculum.fetch(track: track, level: 'HSK 1-2');
    if (mat != null) {
      dailyMaterial = mat;
      notifyListeners();
    }
    curriculumLoading = false;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    if (!auth.signedIn) return;
    final p = await auth.fetchProfile();
    if (p != null) {
      profileName = p.displayName.isNotEmpty ? p.displayName : p.handle;
      profileHandle = p.handle;
      profileId = '#${p.publicId}';
      track = p.track;
      if (track != 'both') primary = track;
      xp = p.xp;
      streak = p.streak;
      avatarUrl = p.avatarUrl;
      lastActiveDate = p.lastActiveDate;
      onboarded = true;
      _registerAttendanceToday();
      refreshLeaderboard();
      refreshMyRooms();
    }
    notifyListeners();
  }

  /// The signed-in user's rank on the global leaderboard (0 = not ranked yet).
  int get myRank {
    for (final r in leaderRows) {
      if (r.you) return r.rank;
    }
    return 0;
  }

  /// Loads the global leaderboard from real profile data. Empty in guest mode.
  Future<void> refreshLeaderboard() async {
    if (!auth.signedIn) {
      leaderRows = [];
      notifyListeners();
      return;
    }
    final rows = await auth.fetchLeaderboard();
    String nameOf(Map<String, dynamic> r) {
      final dn = (r['display_name'] as String?)?.trim() ?? '';
      return dn.isNotEmpty ? dn : (r['handle'] as String? ?? '—');
    }

    leaderRows = [
      for (var i = 0; i < rows.length; i++)
        LeaderRow(
          i + 1,
          nameOf(rows[i]),
          '#${rows[i]['public_id']}',
          (rows[i]['xp'] as num?)?.toInt() ?? 0,
          (rows[i]['handle'] as String?) == profileHandle,
          nameOf(rows[i]).isEmpty
              ? '?'
              : nameOf(rows[i]).substring(0, 1).toUpperCase(),
          tierForXp((rows[i]['xp'] as num?)?.toInt() ?? 0),
        ),
    ];
    notifyListeners();
  }

  void _resetProfileToGuest() {
    profileName = 'Murid';
    profileHandle = '';
    profileId = '';
    avatarUrl = null;
    xp = 0;
    streak = 0;
    lastTestPct = 0;
    onboarded = false;
  }

  /// Counts today's app-open toward the consecutive-day study streak.
  void _registerAttendanceToday() {
    final today = _dateStr(DateTime.now());
    if (lastActiveDate == today) return; // already counted today
    final yesterday = _dateStr(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    streak = (lastActiveDate == yesterday) ? streak + 1 : 1;
    lastActiveDate = today;
    _save();
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // ---- auth actions (UI) ----
  Future<bool> register({
    required String email,
    required String password,
    required String handle,
    String displayName = '',
  }) async {
    authBusy = true;
    authError = null;
    notifyListeners();
    final err = await auth.signUp(
      email: email.trim(),
      password: password,
      handle: handle.trim(),
      displayName: displayName.trim().isEmpty
          ? handle.trim()
          : displayName.trim(),
      track: track,
    );
    authBusy = false;
    if (err != null) {
      authError = err;
      notifyListeners();
      return false;
    }
    if (auth.signedIn) {
      await _loadProfile(); // email confirmation disabled → straight in
    } else {
      authError = 'Akun dibuat. Cek email untuk konfirmasi, lalu masuk.';
      notifyListeners();
    }
    return true;
  }

  Future<bool> login({required String email, required String password}) async {
    authBusy = true;
    authError = null;
    notifyListeners();
    final err = await auth.signIn(email: email.trim(), password: password);
    authBusy = false;
    if (err != null) {
      authError = err;
      notifyListeners();
      return false;
    }
    await _loadProfile();
    return true;
  }

  Future<void> logout() async {
    await auth.signOut();
    _resetProfileToGuest();
    notifyListeners();
  }

  /// Changes the username (handle). Returns null on success or an error string.
  Future<String?> changeUsername(String handle) async {
    final h = handle.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(h)) {
      return 'Username: 3-20 karakter, huruf kecil/angka/garis bawah.';
    }
    if (!auth.signedIn) return 'Hanya bisa diubah saat masuk akun.';
    final err = await auth.updateUsername(h);
    if (err == null) {
      profileHandle = h;
      notifyListeners();
      refreshLeaderboard();
    }
    return err;
  }

  bool avatarBusy = false;

  /// Uploads a new profile picture from raw image [bytes] of type [ext].
  Future<void> setAvatar(Uint8List bytes, String ext) async {
    if (!auth.signedIn) return;
    avatarBusy = true;
    notifyListeners();
    final url = await auth.uploadAvatar(bytes, ext);
    if (url != null) avatarUrl = url;
    avatarBusy = false;
    notifyListeners();
  }

  void clearAuthError() {
    if (authError != null) {
      authError = null;
      notifyListeners();
    }
  }

  void _seedFresh() {
    // Build cards 0..n from seed vocab, then the demo decks referencing them.
    final seedIds = <int>[];
    for (final v in seedVocab) {
      final id = _nextId++;
      cards[id] = v;
      srs[id] = SrsState();
      seedIds.add(id);
    }
    for (final d in seedDeckDefs) {
      decks.add(
        Deck(
          id: 'seed_${d.idx}',
          displayIdx: d.idx,
          name: d.name,
          cardIds: d.cards.map((i) => seedIds[i]).toList(),
        ),
      );
    }
    onboarded = false;
    _save();
  }

  void _restore(Map<String, dynamic> j) {
    onboarded = j['onboarded'] as bool? ?? false;
    themeMode = j['themeMode'] as String? ?? 'system';
    track = j['track'] as String? ?? 'both';
    primary = j['primary'] as String? ?? 'simplified';
    zhuyin = j['zhuyin'] as bool? ?? true;
    xp = j['xp'] as int? ?? 0;
    streak = j['streak'] as int? ?? 0;
    lastTestPct = j['lastTestPct'] as int? ?? 0;
    lastUjianAkhirPct = j['lastUjianAkhirPct'] as int? ?? 0;
    lastActiveDate = j['lastActiveDate'] as String?;
    _nextId = j['nextId'] as int? ?? 0;
    installedPacks
      ..clear()
      ..addAll((j['installedPacks'] as List? ?? []).map((e) => e as String));
    (j['cards'] as Map? ?? {}).forEach((k, v) {
      cards[int.parse(k as String)] = VocabEntry.fromJson(
        v as Map<String, dynamic>,
      );
    });
    (j['srs'] as Map? ?? {}).forEach((k, v) {
      srs[int.parse(k as String)] = SrsState.fromJson(
        v as Map<String, dynamic>,
      );
    });
    decks
      ..clear()
      ..addAll(
        (j['decks'] as List? ?? []).map(
          (e) => Deck.fromJson(e as Map<String, dynamic>),
        ),
      );
    messages = (j['chatHistory'] as List? ?? [])
        .whereType<Map>()
        .map((e) => ChatMsg.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.text.trim().isNotEmpty)
        .take(_maxChatHistory)
        .toList();
    trHistory = (j['translateHistory'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TranslateHistoryItem.fromJson(Map<String, dynamic>.from(e)))
        .where((h) => h.source.trim().isNotEmpty && h.translation.isNotEmpty)
        .take(_maxTranslateHistory)
        .toList();
    // safety: ensure every card has an srs row
    for (final id in cards.keys) {
      srs.putIfAbsent(id, () => SrsState());
    }
  }

  Future<void> _save() async {
    await _store.save({
      'onboarded': onboarded,
      'themeMode': themeMode,
      'track': track,
      'primary': primary,
      'zhuyin': zhuyin,
      'xp': xp,
      'streak': streak,
      'lastTestPct': lastTestPct,
      'lastUjianAkhirPct': lastUjianAkhirPct,
      'lastActiveDate': lastActiveDate,
      'nextId': _nextId,
      'installedPacks': installedPacks.toList(),
      'cards': cards.map((k, v) => MapEntry('$k', v.toJson())),
      'srs': srs.map((k, v) => MapEntry('$k', v.toJson())),
      'decks': decks.map((d) => d.toJson()).toList(),
      'chatHistory': messages
          .take(_maxChatHistory)
          .map((m) => m.toJson())
          .toList(),
      'translateHistory': trHistory
          .take(_maxTranslateHistory)
          .map((h) => h.toJson())
          .toList(),
    });
    // Best-effort sync of progress to the cloud profile when signed in.
    if (auth.signedIn) {
      auth.pushStats(xp: xp, streak: streak, lastActiveDate: lastActiveDate);
    }
  }

  Future<void> _loadPackCatalog() async {
    try {
      final raw = await rootBundle.loadString('assets/packs/manifest.json');
      final list = jsonDecode(raw) as List;
      packCatalog
        ..clear()
        ..addAll(list.map((e) => PackInfo.fromJson(e as Map<String, dynamic>)));
    } catch (e) {
      if (kDebugMode) debugPrint('[packs] manifest load failed: $e');
    }
  }

  // ===========================================================================
  // HELPERS
  // ===========================================================================

  VocabEntry card(int id) => cards[id] ?? seedVocab.first;

  String primaryHanzi(VocabEntry c) {
    if (track == 'traditional') return c.traditional;
    if (track == 'simplified') return c.simplified;
    return primary == 'traditional' ? c.traditional : c.simplified;
  }

  String normalize(String s) {
    final lower = s.toLowerCase();
    const map = {
      'ā': 'a',
      'á': 'a',
      'ǎ': 'a',
      'à': 'a',
      'ē': 'e',
      'é': 'e',
      'ě': 'e',
      'è': 'e',
      'ī': 'i',
      'í': 'i',
      'ǐ': 'i',
      'ì': 'i',
      'ō': 'o',
      'ó': 'o',
      'ǒ': 'o',
      'ò': 'o',
      'ū': 'u',
      'ú': 'u',
      'ǔ': 'u',
      'ù': 'u',
      'ǖ': 'u',
      'ǘ': 'u',
      'ǚ': 'u',
      'ǜ': 'u',
      'ü': 'u',
    };
    final buf = StringBuffer();
    for (final ch in lower.split('')) {
      final m = map[ch] ?? ch;
      if (RegExp(r'[a-z]').hasMatch(m)) buf.write(m);
    }
    return buf.toString();
  }

  String _cleanMeaningInput(String raw) {
    final parts = VocabEntry.splitMeanings(raw);
    return parts.isEmpty ? '(arti)' : parts.join(' / ');
  }

  void _speak(String txt) =>
      speech.speak(txt, traditional: track == 'traditional');

  /// All card ids that are due or new, due-first — the real FSRS review queue.
  List<int> reviewQueue() {
    final now = DateTime.now();
    final ids = cards.keys.toList();
    ids.sort((a, b) {
      final sa = srs[a]!, sb = srs[b]!;
      return sa.due.compareTo(sb.due);
    });
    final due = ids.where((id) {
      final s = srs[id]!;
      return s.isNew || s.isDue(now);
    }).toList();
    return due;
  }

  int get dueCount => reviewQueue().length;

  int get currentQuestionMax {
    final ids = (baseCards.isEmpty ? cards.keys : baseCards)
        .where((id) => cards.containsKey(id))
        .toSet();
    return ids.isEmpty ? 1 : ids.length;
  }

  String get questionLimitLabel {
    final max = currentQuestionMax;
    return 'Kelipatan 10 · maksimal $max sesuai deck';
  }

  int get _questionFloor => math.min(10, currentQuestionMax);

  void _clampQCount() {
    final max = currentQuestionMax;
    qCount = qCount.clamp(_questionFloor, max);
  }

  List<int> makeSession(List<int> base, int n) {
    final b = (base.isEmpty ? cards.keys.toList() : List.of(base))
        .where((id) => cards.containsKey(id))
        .toSet()
        .toList();
    if (b.isEmpty) return [];
    b.shuffle(rng);
    return b.take(math.min(n, b.length)).toList();
  }

  List<String> _makeOptions(int cardId) {
    if (testDirection == 'id2zh') {
      // id→zh: distractors are other hanzi
      final correct = primaryHanzi(card(cardId));
      final pool = cards.entries
          .where((e) => e.key != cardId)
          .map((e) => primaryHanzi(e.value))
          .where((h) => h != correct)
          .toSet()
          .toList();
      pool.shuffle(rng);
      final distract = pool.take(3).toList();
      while (distract.length < 3) {
        distract.add(correct);
      }
      final opts = [correct, ...distract]..shuffle(rng);
      return opts;
    }
    // zh→id: distractors are other meanings (original behavior)
    final correct = card(cardId).primaryMeaning;
    final pool = cards.entries
        .where((e) => e.key != cardId && e.value.primaryMeaning != correct)
        .map((e) => e.value.primaryMeaning)
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    pool.shuffle(rng);
    final distract = pool.take(3).toList();
    while (distract.length < 3) {
      distract.add(correct);
    }
    final opts = [correct, ...distract]..shuffle(rng);
    return opts;
  }

  List<QuizItem> _buildQuiz(List<int> ids) {
    if (testDirection == 'id2zh') {
      return ids
          .map(
            (id) => QuizItem(
              cardId: id,
              correct: primaryHanzi(card(id)),
              options: _makeOptions(id),
            ),
          )
          .toList();
    }
    return ids
        .map(
          (id) => QuizItem(
            cardId: id,
            correct: card(id).primaryMeaning,
            options: _makeOptions(id),
          ),
        )
        .toList();
  }

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void go(String t) {
    _speedTimer?.cancel();
    recording = false;
    tab = t;
    sub = null;
    _deckCtx = null;
    closeRoomChannel();
    leaderOpen = false;
    adding = false;
    notifyListeners();
  }

  void closeSub() {
    _speedTimer?.cancel();
    if (_deckCtx != null && sub != 'deck') {
      sub = 'deck';
      flipped = false;
      adding = false;
    } else {
      sub = null;
      flipped = false;
      _deckCtx = null;
      adding = false;
    }
    notifyListeners();
  }

  /// Removes a deck. If it was an installed pack, frees it for re-download.
  void deleteDeck(String id) {
    decks.removeWhere((d) => d.id == id);
    if (openDeckId == id) openDeckId = null;
    if (sub == 'deck') sub = null;
    if (id.startsWith('pack_')) installedPacks.remove(id.substring(5));
    notifyListeners();
    _save();
  }

  void openLeader() {
    leaderOpen = true;
    notifyListeners();
    refreshLeaderboard();
  }

  void closeLeader() {
    leaderOpen = false;
    notifyListeners();
  }

  /// Loads the user's rooms from the backend (no-op in guest mode).
  Future<void> refreshMyRooms() async {
    if (!rooms.enabled || !signedIn) {
      myRooms = [];
      notifyListeners();
      return;
    }
    myRooms = await rooms.myRooms();
    notifyListeners();
  }

  /// Creates a room, then opens it.
  Future<String?> createRoom(String name) async {
    final level = _levelTag();
    final r = await rooms.createRoom(name, level);
    if (r == null) return 'Gagal membuat ruang.';
    await refreshMyRooms();
    await openRoomById(r);
    return null;
  }

  /// Joins a room by invite code, then opens it.
  Future<String?> joinRoom(String rawCode) async {
    final code = normalizeRoomCode(rawCode);
    if (!isValidRoomCode(code)) return 'Kode tidak valid (cth. ZWS-7F3KQ).';
    final r = await rooms.joinRoom(code);
    if (r == null) return 'Ruang tidak ditemukan.';
    await refreshMyRooms();
    await openRoomById(r);
    return null;
  }

  /// Opens a room: loads history and subscribes to realtime updates.
  Future<void> openRoomById(Room room) async {
    closeRoomChannel();
    currentRoom = room;
    roomMsgs = [];
    roomOnline = 0;
    roomLoading = true;
    notifyListeners();
    roomMsgs = await rooms.history(room.id);
    roomLoading = false;
    _roomChannel = rooms.subscribe(
      room.id,
      presencePayload: {'user_id': authUid, 'handle': profileHandle},
      onMessage: (m) {
        // Already have this exact row (e.g. a duplicate event) — skip.
        if (m.id != 0 && roomMsgs.any((x) => x.id == m.id)) return;
        // Reconcile my optimistic echo (id 0, same body) with the real row.
        if (m.isMine(authUid)) {
          final i = roomMsgs.indexWhere(
            (x) => x.id == 0 && x.isMine(authUid) && x.body == m.body,
          );
          if (i >= 0) {
            roomMsgs = [...roomMsgs]..[i] = m;
            notifyListeners();
            return;
          }
        }
        roomMsgs = [...roomMsgs, m];
        if (m.isGuru) roomGuruBusy = false;
        notifyListeners();
      },
      onPresence: (n) {
        roomOnline = n;
        notifyListeners();
      },
    );
    notifyListeners();
  }

  /// Leaves the current room view (unsubscribes); keeps membership.
  void closeRoomChannel() {
    final ch = _roomChannel;
    _roomChannel = null;
    currentRoom = null;
    roomMsgs = [];
    roomOnline = 0;
    roomGuruBusy = false;
    if (ch != null) {
      try {
        ch.unsubscribe();
      } catch (_) {}
    }
  }

  /// Leaves the room (drops membership) and returns to the room list.
  Future<void> leaveCurrentRoom() async {
    final r = currentRoom;
    if (r == null) return;
    await rooms.leaveRoom(r.id);
    closeRoomChannel();
    await refreshMyRooms();
  }

  /// Owner-only: disbands the current room.
  Future<void> deleteCurrentRoom() async {
    final r = currentRoom;
    if (r == null) return;
    await rooms.deleteRoom(r.id);
    closeRoomChannel();
    await refreshMyRooms();
  }

  bool get isRoomOwner => currentRoom != null && currentRoom!.owner == authUid;

  String _levelTag() {
    switch (track) {
      case 'traditional':
        return '繁體 TOCFL';
      case 'simplified':
        return 'HSK';
      default:
        return 'HSK · TOCFL';
    }
  }

  void setGuruTab(String t) {
    guruTab = t;
    notifyListeners();
  }

  void setChatTab(String t) {
    chatTab = t;
    notifyListeners();
    if (t == 'grup' && currentRoom == null) refreshMyRooms();
  }

  void goVoice() {
    tab = 'chat';
    sub = null;
    chatTab = 'ai';
    guruTab = 'voice';
    notifyListeners();
  }

  // ===========================================================================
  // ONBOARDING / SETTINGS
  // ===========================================================================

  void setTrack(String t) {
    track = t;
    if (t != 'both') primary = t;
    notifyListeners();
    _save();
    if (auth.signedIn) auth.updateTrack(t); // sync to profile (best-effort)
  }

  void finishOnboard() {
    onboarded = true;
    notifyListeners();
    _save();
  }

  void resetOnboard() {
    onboarded = false;
    sub = null;
    notifyListeners();
    _save();
  }

  void setTheme(String mode) {
    themeMode = mode;
    notifyListeners();
    _save();
  }

  void toggleZhuyin() {
    zhuyin = !zhuyin;
    notifyListeners();
    _save();
  }

  // ===========================================================================
  // COUNT STEPPER
  // ===========================================================================

  void incCount() {
    final max = currentQuestionMax;
    if (qCount >= max) {
      qCount = max;
    } else {
      qCount = math.min(max, qCount + 10);
    }
    notifyListeners();
  }

  void decCount() {
    final max = currentQuestionMax;
    final floor = _questionFloor;
    if (qCount == max && max > floor && max % 10 != 0) {
      qCount = math.max(floor, (max ~/ 10) * 10);
    } else {
      qCount = math.max(floor, qCount - 10);
    }
    notifyListeners();
  }

  // ===========================================================================
  // DECKS / AUTHORING
  // ===========================================================================

  Deck? get openDeck =>
      openDeckId == null ? null : decks.firstWhere((d) => d.id == openDeckId);

  void openDeckById(String id) {
    openDeckId = id;
    _deckCtx = id;
    final d = decks.firstWhere((x) => x.id == id);
    baseCards = List.of(d.cardIds);
    _clampQCount();
    sub = 'deck';
    adding = false;
    notifyListeners();
  }

  void setAdding(bool v) {
    adding = v;
    deckIoMsg = '';
    notifyListeners();
  }

  Future<void> exportOpenDeck({required bool excel}) async {
    final d = openDeck;
    if (d == null) return;
    deckIoMsg = 'Menyiapkan export...';
    notifyListeners();
    try {
      final path = await deckIo.exportDeck(
        deckName: d.name,
        cards: d.cardIds.map(card),
        excel: excel,
      );
      deckIoMsg = path == null ? 'Export dibatalkan.' : 'Deck diexport: $path';
    } catch (e) {
      deckIoMsg = 'Export gagal: $e';
    }
    notifyListeners();
  }

  Future<void> importIntoOpenDeck() async {
    final d = openDeck;
    if (d == null) return;
    deckIoMsg = 'Membuka file import...';
    notifyListeners();
    try {
      final result = await deckIo.importDeck();
      if (result == null) {
        deckIoMsg = 'Import dibatalkan.';
      } else if (result.cards.isEmpty) {
        deckIoMsg = 'Tidak ada kartu valid di ${result.sourceName}.';
      } else {
        for (final vocab in result.cards) {
          d.cardIds.add(_addCard(vocab));
        }
        deckIoMsg =
            '${result.cards.length} kartu diimport dari ${result.sourceName}.';
        await _loadTranslationDict();
        await _save();
      }
    } catch (e) {
      deckIoMsg = 'Import gagal: $e';
    }
    notifyListeners();
  }

  /// Review the currently open deck (keeps deck context for back-nav).
  void deckReview() {
    final d = openDeck;
    if (d == null) return;
    startReview(
      d.cardIds.isEmpty
          ? makeSession(cards.keys.toList(), qCount)
          : List.of(d.cardIds),
      'srs',
    );
  }

  /// Open the test picker for the currently open deck (keeps deck context).
  void deckTest() {
    final d = openDeck;
    if (d == null) return;
    baseCards = d.cardIds.isEmpty
        ? cards.keys.take(1).toList()
        : List.of(d.cardIds);
    _clampQCount();
    sub = 'testpick';
    notifyListeners();
  }

  int _addCard(VocabEntry v) {
    final id = _nextId++;
    cards[id] = v;
    srs[id] = SrsState();
    return id;
  }

  void saveCardToOpenDeck(String han, String py, String meaning) {
    final d = openDeck;
    if (han.trim().isEmpty || d == null) return;
    final id = _addCard(
      VocabEntry(
        simplified: han.trim(),
        traditional: han.trim(),
        pinyin: py.trim().isEmpty ? '—' : py.trim(),
        meaning: _cleanMeaningInput(meaning),
      ),
    );
    d.cardIds.add(id);
    adding = false;
    notifyListeners();
    _save();
  }

  // ===========================================================================
  // REVIEW / SELF-CHECK (FSRS)
  // ===========================================================================

  void _recordPractice(
    int id,
    bool correct, {
    int xpCorrect = 2,
    int xpWrong = 1,
  }) {
    if (!cards.containsKey(id)) return;
    final prev = srs[id] ?? SrsState();
    srs[id] = _fsrs.review(prev, correct ? Grade.good : Grade.again);
    xp += correct ? xpCorrect : xpWrong;
  }

  void startReview(List<int> ids, String mode) {
    sessionCards = ids.isEmpty ? makeSession(baseCards, qCount) : List.of(ids);
    reviewMode = mode;
    sub = 'review';
    reviewIdx = 0;
    flipped = false;
    reviewScore = 0;
    notifyListeners();
  }

  void startReviewFromQueue() {
    final q = reviewQueue();
    final ids = q.isEmpty ? makeSession(cards.keys.toList(), qCount) : q;
    _deckCtx = null;
    startReview(ids, 'srs');
  }

  void flipCard() {
    flipped = !flipped;
    notifyListeners();
  }

  void speakCurrentReview() {
    final id = sessionCards[math.min(reviewIdx, sessionCards.length - 1)];
    _speak(primaryHanzi(card(id)));
  }

  void rate(bool correct) {
    final id = sessionCards[math.min(reviewIdx, sessionCards.length - 1)];
    _recordPractice(id, correct);
    if (reviewMode == 'self') {
      if (correct) reviewScore++;
    }
    reviewIdx++;
    flipped = false;
    if (reviewIdx >= sessionCards.length) {
      if (reviewMode == 'self') {
        lastTestPct = ((reviewScore / sessionCards.length) * 100).round();
      }
    }
    _save();
    notifyListeners();
  }

  // ===========================================================================
  // TEST PICKER + MODES
  // ===========================================================================

  void goTestPick({List<int>? base}) {
    if (base != null) baseCards = base;
    openDeckId = null;
    _deckCtx = null;
    _clampQCount();
    sub = 'testpick';
    notifyListeners();
  }

  void toggleTestDirection() {
    testDirection = testDirection == 'zh2id' ? 'id2zh' : 'zh2id';
    notifyListeners();
  }

  void startMc() {
    sessionCards = makeSession(baseCards, qCount);
    _quiz = _buildQuiz(sessionCards);
    sub = 'quiz';
    quizIdx = 0;
    quizScore = 0;
    quizPicked = null;
    notifyListeners();
  }

  void startSelf() => startReview(makeSession(baseCards, qCount), 'self');

  void startSpell() {
    sessionCards = makeSession(baseCards, qCount);
    sub = 'spell';
    spellIdx = 0;
    spellInput = '';
    spellChecked = false;
    spellCorrect = false;
    spellScore = 0;
    notifyListeners();
  }

  // MC
  QuizItem? get currentQuiz => (quizIdx < _quiz.length) ? _quiz[quizIdx] : null;
  int get quizTotal => _quiz.isEmpty ? 1 : _quiz.length;
  List<QuizItem> get quiz => _quiz;

  void pickQuiz(String opt) {
    if (quizPicked != null) return;
    final q = _quiz[quizIdx];
    final correct = opt == q.correct;
    if (correct) quizScore++;
    _recordPractice(q.cardId, correct, xpCorrect: 0, xpWrong: 0);
    quizPicked = opt;
    notifyListeners();
  }

  void nextQuiz() {
    quizIdx++;
    quizPicked = null;
    if (quizIdx >= quizTotal) {
      lastTestPct = ((quizScore / quizTotal) * 100).round();
      xp += quizScore;
      _save();
    }
    notifyListeners();
  }

  void restartQuiz() {
    _quiz = _buildQuiz(sessionCards);
    quizIdx = 0;
    quizScore = 0;
    quizPicked = null;
    notifyListeners();
  }

  // Spelling
  int get spellCardId =>
      sessionCards[math.min(spellIdx, sessionCards.length - 1)];

  void setSpellInput(String v) {
    spellInput = v;
  }

  void checkSpell() {
    if (spellChecked) return;
    final c = card(spellCardId);
    final input = spellInput.trim();
    spellCorrect =
        normalize(input) == normalize(c.pinyin) ||
        input == primaryHanzi(c) ||
        c.matchesMeaning(input);
    spellChecked = true;
    if (spellCorrect) spellScore++;
    _recordPractice(spellCardId, spellCorrect, xpCorrect: 0, xpWrong: 0);
    notifyListeners();
  }

  void nextSpell() {
    spellIdx++;
    spellInput = '';
    spellChecked = false;
    spellCorrect = false;
    if (spellIdx >= sessionCards.length) {
      lastTestPct = ((spellScore / sessionCards.length) * 100).round();
      _save();
    }
    notifyListeners();
  }

  void restartSpell() {
    spellIdx = 0;
    spellInput = '';
    spellChecked = false;
    spellCorrect = false;
    spellScore = 0;
    notifyListeners();
  }

  // ===========================================================================
  // GAMES HUB
  // ===========================================================================

  void goGames() {
    _speedTimer?.cancel();
    recording = false;
    sub = 'games';
    notifyListeners();
  }

  // Tone
  ({String han, String pinyin, int tone}) get toneCur =>
      toneBank[toneIdx % toneBank.length];
  int get toneTotal => qCount;

  void startTone() {
    sub = 'tone';
    toneIdx = 0;
    toneScore = 0;
    tonePicked = null;
    notifyListeners();
    Future.delayed(
      const Duration(milliseconds: 250),
      () => _speak(toneCur.han),
    );
  }

  void pickTone(int n) {
    if (tonePicked != null) return;
    tonePicked = n;
    if (n == toneCur.tone) toneScore++;
    notifyListeners();
  }

  void nextTone() {
    toneIdx++;
    tonePicked = null;
    if (toneIdx < toneTotal) {
      Future.delayed(
        const Duration(milliseconds: 250),
        () => _speak(toneCur.han),
      );
    } else {
      xp += toneScore;
      _save();
    }
    notifyListeners();
  }

  void replayTone() => _speak(toneCur.han);

  // Match
  List<int> get matchPairs => _matchPairs;
  List<({int pid, String kind, String label})> get matchTiles => _matchTiles;

  void startMatch() {
    var base = {
      ...(baseCards.isEmpty ? cards.keys.take(6) : baseCards),
    }.toList();
    if (base.length < 4) base = cards.keys.take(6).toList();
    _matchPairs = base.take(6).toList();
    final tiles = <({int pid, String kind, String label})>[];
    for (final id in _matchPairs) {
      tiles.add((pid: id, kind: 'han', label: primaryHanzi(card(id))));
      tiles.add((pid: id, kind: 'm', label: card(id).primaryMeaning));
    }
    tiles.shuffle(rng);
    _matchTiles = tiles;
    sub = 'match';
    matchMatched = [];
    matchSel = null;
    matchWrong = [];
    matchMoves = 0;
    notifyListeners();
  }

  void matchTap(int tileIdx) {
    final tile = _matchTiles[tileIdx];
    if (matchMatched.contains(tile.pid) || matchWrong.isNotEmpty) return;
    if (matchSel == null) {
      matchSel = tileIdx;
      notifyListeners();
      return;
    }
    if (matchSel == tileIdx) {
      matchSel = null;
      notifyListeners();
      return;
    }
    final sel = _matchTiles[matchSel!];
    matchMoves++;
    if (sel.pid == tile.pid && sel.kind != tile.kind) {
      matchMatched = [...matchMatched, tile.pid];
      _recordPractice(tile.pid, true, xpCorrect: 0, xpWrong: 0);
      matchSel = null;
      if (matchMatched.length >= _matchPairs.length) {
        xp += 5;
        _save();
      }
    } else {
      matchWrong = [matchSel!, tileIdx];
      matchSel = null;
      Future.delayed(const Duration(milliseconds: 700), () {
        matchWrong = [];
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // Listening
  void goListen() {
    sessionCards = makeSession(baseCards, qCount);
    _quiz = _buildQuiz(sessionCards);
    sub = 'listen';
    quizIdx = 0;
    quizScore = 0;
    quizPicked = null;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 350), playListenCur);
  }

  void playListenCur() {
    final q = currentQuiz;
    if (q != null) _speak(primaryHanzi(card(q.cardId)));
  }

  void nextListen() {
    quizIdx++;
    quizPicked = null;
    if (quizIdx >= quizTotal) {
      xp += quizScore;
      _save();
    }
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 350), playListenCur);
  }

  // Speed
  List<QuizItem> get speed => _speed;
  int get speedTotal => sessionCards.length;
  QuizItem? get speedCur => speedIdx < _speed.length ? _speed[speedIdx] : null;

  void startSpeed() {
    sessionCards = makeSession(baseCards, qCount);
    _speed = _buildQuiz(sessionCards);
    _speedTimer?.cancel();
    sub = 'speed';
    speedIdx = 0;
    speedScore = 0;
    speedLeft = 45;
    notifyListeners();
    _speedTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (speedLeft <= 1) {
        speedLeft = 0;
        t.cancel();
        xp += speedScore;
        _save();
      } else {
        speedLeft--;
      }
      notifyListeners();
    });
  }

  void speedPick(String opt) {
    final cur = speedCur;
    if (cur == null) return;
    final correct = opt == cur.correct;
    if (correct) speedScore++;
    _recordPractice(cur.cardId, correct, xpCorrect: 0, xpWrong: 0);
    speedIdx++;
    if (speedIdx >= _speed.length) {
      _speedTimer?.cancel();
      xp += speedScore;
      _save();
    }
    notifyListeners();
  }

  // ===========================================================================
  // WRITE (standalone)
  // ===========================================================================

  void openWrite() {
    sub = 'write';
    writeDeck = 0;
    writeMsg = '';
    notifyListeners();
  }

  void closeWrite() {
    sub = null;
    writeMsg = '';
    notifyListeners();
  }

  void setWriteDeck(int i) {
    writeDeck = i;
    notifyListeners();
  }

  void saveWrite(String han, String py, String meaning) {
    if (han.trim().isEmpty || decks.isEmpty) return;
    final deck = decks[writeDeck.clamp(0, decks.length - 1)];
    final id = _addCard(
      VocabEntry(
        simplified: han.trim(),
        traditional: han.trim(),
        pinyin: py.trim().isEmpty ? '—' : py.trim(),
        meaning: _cleanMeaningInput(meaning),
      ),
    );
    deck.cardIds.add(id);
    writeMsg = 'Tersimpan ke ${deck.name} ✓';
    notifyListeners();
    _save();
    Future.delayed(const Duration(milliseconds: 2600), () {
      writeMsg = '';
      notifyListeners();
    });
  }

  // ===========================================================================
  // PACKS
  // ===========================================================================

  bool isInstalled(String packId) => installedPacks.contains(packId);

  Future<void> installPack(PackInfo pack) async {
    if (installedPacks.contains(pack.id)) return;
    try {
      final raw = await rootBundle.loadString(pack.asset);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['cards'] as List).cast<Map<String, dynamic>>();
      final deck = Deck(
        id: 'pack_${pack.id}',
        displayIdx: (decks.length + 1).toString().padLeft(2, '0'),
        name: pack.name,
        standard: pack.standard,
        levelTag: pack.levelTag,
        isPack: true,
      );
      for (final cj in list) {
        final id = _addCard(VocabEntry.fromJson(cj));
        deck.cardIds.add(id);
      }
      decks.add(deck);
      installedPacks.add(pack.id);
      _loadTranslationDict(); // reload dict with new cards
      xp += 10;
      notifyListeners();
      await _save();
    } catch (e) {
      if (kDebugMode) debugPrint('[packs] install ${pack.id} failed: $e');
    }
  }

  String _cardSignature(VocabEntry v) {
    final s = v.simplified.trim();
    final t = v.traditional.trim();
    final py = normalize(v.pinyin);
    return '$s|$t|$py';
  }

  SrsState _copySrs(SrsState s) => SrsState.fromJson(s.toJson());

  Map<String, List<SrsState>> _srsByCardSignature(Iterable<int> ids) {
    final out = <String, List<SrsState>>{};
    for (final id in ids) {
      final v = cards[id];
      final state = srs[id];
      if (v == null || state == null) continue;
      out
          .putIfAbsent(_cardSignature(v), () => <SrsState>[])
          .add(_copySrs(state));
    }
    return out;
  }

  int _addCardWithSrs(VocabEntry v, SrsState state) {
    final id = _nextId++;
    cards[id] = v;
    srs[id] = state;
    return id;
  }

  void _removeCardsIfUnreferenced(
    Iterable<int> ids, {
    required String exceptDeckId,
  }) {
    final referenced = <int>{};
    for (final d in decks) {
      if (d.id == exceptDeckId) continue;
      referenced.addAll(d.cardIds);
    }
    for (final id in ids) {
      if (referenced.contains(id)) continue;
      cards.remove(id);
      srs.remove(id);
    }
  }

  Future<void> syncDatabaseUpdate() async {
    if (databaseSyncBusy) return;
    databaseSyncBusy = true;
    databaseSyncMsg = 'Memeriksa database deck terbaru...';
    notifyListeners();
    try {
      await _loadPackCatalog();
      var updatedDecks = 0;
      var updatedCards = 0;
      for (var i = 0; i < decks.length; i++) {
        final deck = decks[i];
        if (!deck.isPack || !deck.id.startsWith('pack_')) continue;
        final packId = deck.id.substring(5);
        final matches = packCatalog.where((p) => p.id == packId).toList();
        if (matches.isEmpty) continue;
        final pack = matches.first;
        final raw = await rootBundle.loadString(pack.asset);
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final list = (data['cards'] as List).cast<Map<String, dynamic>>();
        final oldIds = List<int>.of(deck.cardIds);
        final oldSrs = _srsByCardSignature(oldIds);
        final newIds = <int>[];
        for (final cj in list) {
          final vocab = VocabEntry.fromJson(cj);
          final sig = _cardSignature(vocab);
          final preserved = oldSrs[sig];
          final state = preserved != null && preserved.isNotEmpty
              ? preserved.removeAt(0)
              : SrsState();
          newIds.add(_addCardWithSrs(vocab, state));
        }
        _removeCardsIfUnreferenced(oldIds, exceptDeckId: deck.id);
        decks[i] = Deck(
          id: deck.id,
          displayIdx: deck.displayIdx,
          name: pack.name,
          standard: pack.standard,
          levelTag: pack.levelTag,
          isPack: true,
          cardIds: newIds,
        );
        updatedDecks++;
        updatedCards += newIds.length;
      }
      await _loadTranslationDict();
      _clampQCount();
      databaseSyncMsg = updatedDecks == 0
          ? 'Belum ada pack terpasang yang perlu diupdate.'
          : 'Database diperbarui: $updatedDecks deck, $updatedCards kartu. Penguasaan lama dipertahankan.';
      await _save();
    } catch (e) {
      databaseSyncMsg = 'Update database gagal: $e';
    }
    databaseSyncBusy = false;
    notifyListeners();
  }

  // ===========================================================================
  // TUNER
  // ===========================================================================

  void setTunerTone(int n) {
    tunerTone = n;
    // Re-judge the current attempt against the newly selected target.
    tunerMatch = pitchTrace.length >= 12
        ? toneMatchScore(pitchTrace, tunerTone)
        : 0;
    notifyListeners();
  }

  bool micUnavailable = false;
  double micLevel = 0; // 0..1 input level (so the UI shows audio is arriving)
  String micStatus = '';
  int micFrames = 0; // diagnostics: how many audio frames have arrived
  List<InputDevice> micList = [];
  InputDevice? micDevice; // null = system default

  int get micDevices => micList.length;

  /// Enumerate input devices (for the mic picker).
  Future<void> loadMics() async {
    micList = await _pitch.devices();
    notifyListeners();
  }

  Future<void> _startMic() async {
    pitchTrace = [];
    currentHz = null;
    tunerMatch = 0;
    micLevel = 0;
    micFrames = 0;
    micUnavailable = false;
    _hzWin.clear();
    _smoothHz = null;
    _unvoicedRun = 0;
    _resetTraceOnNextVoice = false;
    final status = await _pitch.start(_onFrame, device: micDevice);
    micStatus = status;
    recording = status.startsWith('ok');
    micUnavailable = !recording;
    notifyListeners();
  }

  Future<void> toggleMic() async {
    if (recording) {
      recording = false;
      micLevel = 0;
      tunerMatch = 0;
      await _pitch.stop();
      notifyListeners();
      return;
    }
    if (micList.isEmpty) await loadMics();
    await _startMic();
  }

  /// Switch the active microphone. If recording, restart the stream on it.
  Future<void> selectMic(InputDevice? d) async {
    micDevice = d;
    notifyListeners();
    if (recording) {
      await _pitch.stop();
      await _startMic();
    }
  }

  final List<double> _hzWin = []; // recent raw pitches (for the median filter)
  double? _smoothHz; // median + light EMA of the detected pitch
  int _unvoicedRun = 0;
  bool _resetTraceOnNextVoice = false; // start a fresh contour per syllable

  void _onFrame(double? hz, double rms) {
    micLevel = (rms * 6).clamp(0.0, 1.0);
    micFrames++;
    if (hz != null) {
      _unvoicedRun = 0;
      // Median filter kills stray octave/spurious frames without lagging the
      // contour the way a heavy EMA does; the light EMA just trims jitter.
      _hzWin.add(hz);
      if (_hzWin.length > 5) _hzWin.removeAt(0);
      final med = _median(_hzWin);
      // Light EMA (mostly the median) — enough to trim jitter without smearing
      // fast tones (T4 falling, T3 dip), which heavier smoothing flattened.
      _smoothHz = _smoothHz == null ? med : _smoothHz! * 0.3 + med * 0.7;
      currentHz = _smoothHz;
      if (_resetTraceOnNextVoice) {
        pitchTrace = [];
        tunerMatch = 0;
        _resetTraceOnNextVoice = false;
      }
      _pushTrace(_smoothHz!);
      // Live shape match once there's enough of the syllable to judge.
      if (pitchTrace.length >= 12) {
        tunerMatch = toneMatchScore(pitchTrace, tunerTone);
      }
    } else {
      // Bridge brief unvoiced gaps so the contour line stays continuous;
      // only break after a real pause — then freeze the syllable and reset on
      // the next voicing so each syllable is normalized & drawn on its own.
      _unvoicedRun++;
      if (_unvoicedRun <= 5 && _smoothHz != null) {
        _pushTrace(_smoothHz!);
      } else {
        _smoothHz = null;
        _hzWin.clear();
        currentHz = null;
        _resetTraceOnNextVoice = true;
      }
    }
    notifyListeners();
  }

  // The trace stores *semitones* of the current syllable; the gauge normalizes
  // the whole syllable by its own range, so the tone shape lines up with the
  // target contour regardless of the speaker's absolute pitch.
  void _pushTrace(double hz) {
    final st = 12 * (math.log(hz) / math.ln2);
    final next = [...pitchTrace, st];
    pitchTrace = next.length > 90 ? next.sublist(next.length - 90) : next;
  }

  static double _median(List<double> v) {
    final s = [...v]..sort();
    final n = s.length;
    return n.isOdd ? s[n ~/ 2] : (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2;
  }

  // ===========================================================================
  // TRANSLATE (text · voice · photo) — LLM engine + dictionary enrichment
  // ===========================================================================

  String trFrom = 'zh'; // 'zh' | 'id'
  String trTo = 'id';
  String trEngine = 'ai'; // 'ai' (LLM, akurat) | 'dict' (kamus, cepat)
  String trSource = '';
  TranslationResult? trResult;
  List<TranslateHistoryItem> trHistory = [];
  static const int _maxTranslateHistory = 80;
  bool trLoading = false;
  String? trError;
  bool trRecording = false; // voice capture in progress
  bool trVoiceBusy = false; // transcribing
  bool trPhotoBusy = false; // OCR in progress
  Timer? _trDebounce;
  int _trSeq = 0; // ignore stale async results

  String get _zhTrack =>
      (track == 'traditional' || (track == 'both' && primary == 'traditional'))
      ? 'traditional'
      : 'simplified';

  void trSetSource(String text) {
    trSource = text;
    trError = null;
    _trDebounce?.cancel();
    if (text.trim().isEmpty) {
      trResult = null;
      trLoading = false;
      notifyListeners();
      return;
    }
    notifyListeners();
    _trDebounce = Timer(const Duration(milliseconds: 550), trTranslateNow);
  }

  Future<void> trTranslateNow() async {
    _trDebounce?.cancel();
    final text = trSource.trim();
    if (text.isEmpty) return;
    final seq = ++_trSeq;
    trLoading = true;
    trError = null;
    notifyListeners();
    final r = await translation.translate(
      text,
      from: trFrom,
      to: trTo,
      track: _zhTrack,
      engine: trEngine,
    );
    if (seq != _trSeq) return; // stale
    trLoading = false;
    if (r == null) {
      trError = translation.lastError ?? 'Gagal menerjemahkan. Coba lagi.';
      notifyListeners();
      return;
    }
    // Jika LLM gagal tapi dictionary fallback jalan, tampilkan warning
    if (translation.lastError != null) {
      trError = 'AI lagi ngadat, pakai kamus: ${translation.lastError}';
    }
    trResult = r;
    _rememberTranslation(text, r);
    await _save();
    notifyListeners();
  }

  void _rememberTranslation(String source, TranslationResult result) {
    final item = TranslateHistoryItem(
      source: source,
      translation: result.translation,
      from: trFrom,
      to: trTo,
      engine: trEngine,
      pinyin: result.pinyin,
      at: DateTime.now(),
    );
    trHistory = [
      item,
      ...trHistory.where(
        (h) =>
            h.source != item.source ||
            h.translation != item.translation ||
            h.from != item.from ||
            h.to != item.to,
      ),
    ].take(_maxTranslateHistory).toList();
  }

  void trUseHistory(TranslateHistoryItem item) {
    _trDebounce?.cancel();
    trFrom = item.from;
    trTo = item.to;
    trEngine = item.engine;
    trSource = item.source;
    trResult = TranslationResult(
      translation: item.translation,
      pinyin: item.pinyin,
    );
    trError = null;
    trLoading = false;
    notifyListeners();
  }

  Future<void> trClearHistory() async {
    trHistory = [];
    await _save();
    notifyListeners();
  }

  void trSetEngine(String engine) {
    trEngine = engine;
    trResult = null;
    trError = null;
    notifyListeners();
    if (trSource.trim().isNotEmpty) trTranslateNow();
  }

  void trSwap() {
    final f = trFrom;
    trFrom = trTo;
    trTo = f;
    final prev = trResult?.translation;
    if (prev != null && prev.trim().isNotEmpty) trSource = prev;
    trResult = null;
    notifyListeners();
    if (trSource.trim().isNotEmpty) trTranslateNow();
  }

  void trClear() {
    _trDebounce?.cancel();
    trSource = '';
    trResult = null;
    trError = null;
    trLoading = false;
    notifyListeners();
  }

  Future<void> trToggleVoice() async {
    if (trRecording) {
      trRecording = false;
      trVoiceBusy = true;
      notifyListeners();
      final text = await _stt.stopAndTranscribe(
        lang: trFrom == 'zh' ? 'zh' : 'id',
      );
      trVoiceBusy = false;
      if (text != null && text.isNotEmpty) {
        trSource = text;
        notifyListeners();
        await trTranslateNow();
      } else {
        trError = 'Tidak ada teks terdeteksi dari suara.';
        notifyListeners();
      }
      return;
    }
    final ok = await _stt.start();
    if (!ok) {
      trError = 'Mikrofon tidak tersedia / izin ditolak.';
      notifyListeners();
      return;
    }
    trRecording = true;
    trError = null;
    notifyListeners();
  }

  Future<void> trPickPhoto() async {
    trPhotoBusy = true;
    trError = null;
    notifyListeners();
    final text = await _ocr.pickAndExtract();
    trPhotoBusy = false;
    if (text != null && text.isNotEmpty) {
      trSource = text;
      notifyListeners();
      await trTranslateNow();
    } else {
      notifyListeners(); // cancelled or nothing recognized
    }
  }

  /// Speak the Chinese side of the current translation (TTS).
  void trSpeakResult() {
    final zh = trTo == 'zh'
        ? trResult?.translation
        : (trFrom == 'zh' ? trSource : null);
    if (zh != null && zh.trim().isNotEmpty) {
      speech.speak(zh, traditional: track == 'traditional');
    }
  }

  // ===========================================================================
  // CHAT (mock; real LLM goes through the llm-proxy Edge Function — PRD §9)
  // ===========================================================================

  static const _tutorReplies = [
    '很好！Kalimatmu sudah benar. Coba ganti objeknya: 我喜欢看书 (saya suka membaca buku).',
    'Bagus. 喜欢 bisa diikuti kata benda atau kata kerja. PR-mu kucatat ke rapor ya.',
    '对！Sekarang coba bentuk negatifnya: 我不喜欢… Apa yang tidak kamu sukai?',
  ];

  void setChatInput(String v) {
    chatInput = v;
  }

  Future<void> sendChat() async {
    final txt = chatInput.trim();
    if (txt.isEmpty) return;
    messages = [...messages, ChatMsg('me', txt)];
    chatInput = '';
    tutorTyping = true;
    notifyListeners();

    String? reply;
    try {
      reply = await llm
          .chat(buildGroundedHistory(_llmHistory(), idiomBank), track: track)
          .timeout(const Duration(seconds: 40));
    } catch (_) {
      llm.lastError = 'Timeout (>40s)';
      reply = null;
    }
    if (reply == null) {
      final err = llm.lastError;
      if (err != null) {
        reply =
            'Guru sedang tidak tersedia: $err\nCoba lagi nanti ya. Sementara kamu bisa latihan flashcard dulu.';
      } else {
        final mine = messages.where((m) => m.who == 'me').length;
        reply = _tutorReplies[(mine - 1) % _tutorReplies.length];
      }
      if (llm.enabled) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    tutorTyping = false;
    messages = [...messages, ChatMsg('t', reply)];
    if (messages.length > _maxChatHistory) {
      messages = messages.sublist(messages.length - _maxChatHistory);
    }
    await _save();
    notifyListeners();
  }

  /// Conversation history for the LLM (maps tutor→assistant, user→user).
  List<Map<String, String>> _llmHistory() => messages
      .where((m) => m.who == 'me' || m.who == 't')
      .map(
        (m) => {'role': m.who == 't' ? 'assistant' : 'user', 'content': m.text},
      )
      .toList();

  /// Minta Guru mengajarkan satu idiom dari bank (akurat karena entri disuntik).
  Future<void> learnIdiomWithGuru({String? cat}) async {
    final it = idiomBank.randomForTeaching(cat: cat);
    if (it == null) return;
    final block = idiomBank.contextBlock([it]);
    messages = [...messages, ChatMsg('me', 'Ajari aku idiom ${it.simplified}')];
    tutorTyping = true;
    notifyListeners();
    String? reply;
    if (llm.enabled && signedIn) {
      final hist = [
        ..._llmHistory(),
        {
          'role': 'user',
          'content':
              'Ajari aku idiom ini: $block. Jelaskan maknanya, asal-usul singkat, '
              'beri 1 contoh kalimat baru, lalu beri aku 1 soal singkat.',
        },
      ];
      reply = await llm.chat(hist, track: track);
    }
    reply ??=
        'Idiom ${it.simplified} (${it.pinyin}) — ${it.meaning}.'
        '${it.literal.isNotEmpty ? ' Harfiah: ${it.literal}.' : ''}';
    tutorTyping = false;
    messages = [...messages, ChatMsg('t', reply)];
    if (messages.length > _maxChatHistory) {
      messages = messages.sublist(messages.length - _maxChatHistory);
    }
    await _save();
    notifyListeners();
  }

  void setRoomInput(String v) {
    roomInput = v;
  }

  /// Sends a message to the current room. If it mentions `@Guru`, also asks the
  /// tutor to reply (server-side, via the `group-guru` Edge Function). The
  /// realtime channel delivers both the echo and the Guru reply to everyone.
  Future<void> sendRoom() async {
    final r = currentRoom;
    final txt = roomInput.trim();
    if (r == null || txt.isEmpty) return;
    roomInput = '';
    // Optimistic echo (id 0) so the sender sees it immediately; the realtime
    // INSERT with the same body arrives shortly after with a real id.
    final me = profileName.isEmpty ? 'Kamu' : profileName;
    roomMsgs = [
      ...roomMsgs,
      RoomMessage(
        id: 0,
        senderId: authUid,
        authorName: me,
        authorHandle: profileHandle,
        body: txt,
        createdAt: DateTime.now(),
      ),
    ];
    final callGuru = mentionsGuru(txt);
    if (callGuru) roomGuruBusy = true;
    notifyListeners();

    await rooms.sendMessage(
      r.id,
      body: txt,
      authorName: me,
      authorHandle: profileHandle,
    );
    if (callGuru) {
      final err = await rooms.callGuru(r.id);
      if (err != null) {
        roomGuruBusy = false;
        notifyListeners();
      }
    }
  }

  // ===========================================================================
  // RAPOR (weighted report card — PRD §11)
  // ===========================================================================

  // Honest, activity-driven report card. A brand-new account is all zeros and
  // fills in as the student attends, tests, and practices. PR (materi guru) and
  // Ujian Akhir stay 0 until those subsystems are built.
  List<({String name, String weight, int score})> get rapor => [
    (name: 'Kehadiran', weight: '10%', score: math.min(100, streak * 10)),
    (name: 'PR (materi guru)', weight: '20%', score: prScore),
    (name: 'Ujian Harian', weight: '20%', score: lastTestPct),
    (name: 'Praktek', weight: '25%', score: math.min(100, (xp / 3).round())),
    (name: 'Ujian Akhir', weight: '25%', score: lastUjianAkhirPct),
  ];

  int get raporTotal {
    const weights = [0.10, 0.20, 0.20, 0.25, 0.25];
    double sum = 0;
    final r = rapor;
    for (var i = 0; i < r.length; i++) {
      sum += r[i].score * weights[i];
    }
    return sum.round();
  }

  /// Start the comprehensive final exam overlay.
  void startUjianAkhir() {
    sub = 'ujian_akhir';
    notifyListeners();
  }

  /// Called when the ujian akhir overlay finishes.
  void finishUjianAkhir(int score, int total) {
    lastUjianAkhirPct = total > 0 ? (score * 100 / total).round() : 0;
    xp += score * 2;
    _save();
  }

  /// Score for PR (materi guru) — tracks how many days curriculum was loaded.
  int get prScore {
    if (dailyMaterial != null) return math.min(100, streak * 10);
    return 0;
  }

  String get raporLetter {
    final t = raporTotal;
    if (t >= 90) return 'A';
    if (t >= 85) return 'A−';
    if (t >= 80) return 'B+';
    if (t >= 75) return 'B';
    if (t >= 70) return 'B−';
    return 'C';
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
    _trDebounce?.cancel();
    _authSub?.cancel();
    closeRoomChannel();
    _pitch.dispose();
    super.dispose();
  }
}
