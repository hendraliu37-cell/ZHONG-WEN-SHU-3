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
import '../services/pronunciation_service.dart';
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

class TestHistoryItem {
  final String id;
  final String mode; // 'mc' | 'self' | 'spell'
  final String title;
  final String? deckId;
  final String direction;
  final List<int> cardIds;
  final int index;
  final int score;
  final String? picked;
  final String spellInput;
  final bool spellChecked;
  final bool spellCorrect;
  final bool flipped;
  final bool completed;
  final DateTime startedAt;
  final DateTime updatedAt;

  const TestHistoryItem({
    required this.id,
    required this.mode,
    required this.title,
    required this.direction,
    required this.cardIds,
    required this.index,
    required this.score,
    this.deckId,
    this.picked,
    this.spellInput = '',
    this.spellChecked = false,
    this.spellCorrect = false,
    this.flipped = false,
    this.completed = false,
    required this.startedAt,
    required this.updatedAt,
  });

  int get total => cardIds.length;
  int get shownIndex => total == 0 ? 0 : index.clamp(0, total);
  int get pct => total == 0 ? 0 : (score * 100 / total).round();

  TestHistoryItem copyWith({
    String? mode,
    String? title,
    String? deckId,
    String? direction,
    List<int>? cardIds,
    int? index,
    int? score,
    Object? picked = _sentinel,
    String? spellInput,
    bool? spellChecked,
    bool? spellCorrect,
    bool? flipped,
    bool? completed,
    DateTime? startedAt,
    DateTime? updatedAt,
  }) => TestHistoryItem(
    id: id,
    mode: mode ?? this.mode,
    title: title ?? this.title,
    deckId: deckId ?? this.deckId,
    direction: direction ?? this.direction,
    cardIds: cardIds ?? this.cardIds,
    index: index ?? this.index,
    score: score ?? this.score,
    picked: identical(picked, _sentinel) ? this.picked : picked as String?,
    spellInput: spellInput ?? this.spellInput,
    spellChecked: spellChecked ?? this.spellChecked,
    spellCorrect: spellCorrect ?? this.spellCorrect,
    flipped: flipped ?? this.flipped,
    completed: completed ?? this.completed,
    startedAt: startedAt ?? this.startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  factory TestHistoryItem.fromJson(Map<String, dynamic> j) => TestHistoryItem(
    id: (j['id'] as String?) ?? '',
    mode: (j['mode'] as String?) ?? 'mc',
    title: (j['title'] as String?) ?? 'Tes',
    deckId: j['deckId'] as String?,
    direction: (j['direction'] as String?) ?? 'zh2id',
    cardIds: ((j['cardIds'] as List?) ?? [])
        .map((e) => (e as num).toInt())
        .toList(),
    index: (j['index'] as num?)?.toInt() ?? 0,
    score: (j['score'] as num?)?.toInt() ?? 0,
    picked: j['picked'] as String?,
    spellInput: (j['spellInput'] as String?) ?? '',
    spellChecked: (j['spellChecked'] as bool?) ?? false,
    spellCorrect: (j['spellCorrect'] as bool?) ?? false,
    flipped: (j['flipped'] as bool?) ?? false,
    completed: (j['completed'] as bool?) ?? false,
    startedAt:
        DateTime.tryParse((j['startedAt'] as String?) ?? '') ?? DateTime.now(),
    updatedAt:
        DateTime.tryParse((j['updatedAt'] as String?) ?? '') ?? DateTime.now(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'mode': mode,
    'title': title,
    if (deckId != null) 'deckId': deckId,
    'direction': direction,
    'cardIds': cardIds,
    'index': index,
    'score': score,
    if (picked != null) 'picked': picked,
    'spellInput': spellInput,
    'spellChecked': spellChecked,
    'spellCorrect': spellCorrect,
    'flipped': flipped,
    'completed': completed,
    'startedAt': startedAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

const Object _sentinel = Object();

const Map<String, String> _simpToTrad = {
  '这': '這',
  '个': '個',
  '们': '們',
  '为': '為',
  '来': '來',
  '说': '說',
  '对': '對',
  '时': '時',
  '会': '會',
  '学': '學',
  '习': '習',
  '书': '書',
  '语': '語',
  '汉': '漢',
  '问': '問',
  '听': '聽',
  '读': '讀',
  '写': '寫',
  '话': '話',
  '请': '請',
  '谢': '謝',
  '欢': '歡',
  '觉': '覺',
  '饭': '飯',
  '饮': '飲',
  '马': '馬',
  '门': '門',
  '车': '車',
  '电': '電',
  '脑': '腦',
  '机': '機',
  '后': '後',
  '里': '裡',
  '着': '著',
  '过': '過',
  '还': '還',
  '没': '沒',
  '气': '氣',
  '国': '國',
  '爱': '愛',
  '长': '長',
  '吗': '嗎',
  '哪': '哪',
  '点': '點',
  '买': '買',
  '卖': '賣',
  '开': '開',
  '关': '關',
};

final Map<String, String> _tradToSimp = {
  for (final e in _simpToTrad.entries) e.value: e.key,
};

String formatTutorReplyForDisplay(
  String text, {
  required String track,
  required String primary,
  Iterable<VocabEntry> cards = const [],
}) => _formatTutorReply(
  _convertHanziForTrack(text, track: track, primary: primary, cards: cards),
);

String _formatTutorReply(String raw) {
  var text = raw
      .replaceAll('\r\n', '\n')
      .replaceAll(RegExp(r'```[a-zA-Z]*'), '')
      .replaceAll('```', '');
  text = text
      .replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m.group(1) ?? '')
      .replaceAllMapped(RegExp(r'__([^_]+)__'), (m) => m.group(1) ?? '')
      .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '')
      .trim();
  if (text.isEmpty) return raw.trim();

  final rawLines = text
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('|'))
      .toList();
  final lines = <String>[];
  for (final line in rawLines) {
    final chunks = line
        .split(
          RegExp(
            r'\s+(?=(Ringkas|Contoh|Catatan|Latihan)\s*:)',
            caseSensitive: false,
          ),
        )
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty);
    lines.addAll(chunks);
  }

  final labelled = <String, String>{};
  final loose = <String>[];
  const labels = ['Ringkas:', 'Contoh:', 'Catatan:', 'Latihan:'];
  for (final line in lines) {
    var cleaned = line.replaceFirst(RegExp(r'^\d+[.)]\s*'), '').trim();
    if (RegExp(
      r'^(jawaban|guru|respons?)$',
      caseSensitive: false,
    ).hasMatch(cleaned)) {
      continue;
    }
    for (final label in labels) {
      final re = RegExp('^${RegExp.escape(label)}\\s*', caseSensitive: false);
      if (re.hasMatch(cleaned)) {
        final body = cleaned.replaceFirst(re, '').trim();
        if (body.isNotEmpty) {
          labelled[label] = _appendBlock(labelled[label], body);
        }
        cleaned = '';
        break;
      }
    }
    if (cleaned.isNotEmpty) loose.add(cleaned);
  }

  if (labelled.isEmpty) {
    for (final line in loose.take(6)) {
      final lower = line.toLowerCase();
      final label = line.endsWith('?')
          ? 'Latihan:'
          : (_looksLikeExample(line)
                ? 'Contoh:'
                : (lower.startsWith('catatan') || lower.contains('jangan ')
                      ? 'Catatan:'
                      : (labelled.containsKey('Ringkas:')
                            ? 'Catatan:'
                            : 'Ringkas:')));
      labelled[label] = _appendBlock(labelled[label], line);
    }
  } else {
    for (final line in loose.take(3)) {
      final label = _looksLikeExample(line) ? 'Contoh:' : 'Catatan:';
      labelled[label] = _appendBlock(labelled[label], line);
    }
  }

  return labels
      .where((label) => labelled[label]?.trim().isNotEmpty == true)
      .map((label) => '$label ${labelled[label]!.trim()}')
      .take(4)
      .join('\n');
}

String _appendBlock(String? existing, String next) {
  final cleaned = next.trim();
  if (cleaned.isEmpty) return existing ?? '';
  if (existing == null || existing.trim().isEmpty) return cleaned;
  return '$existing $cleaned';
}

bool _looksLikeExample(String line) {
  final hasHanzi = RegExp(r'[\u3400-\u9fff]').hasMatch(line);
  final hasGloss = line.contains('=') || line.contains('artinya');
  final hasPinyin = RegExp(
    r'\([A-Za-züÜāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ0-9 ]+\)',
  ).hasMatch(line);
  return hasHanzi && (hasGloss || hasPinyin);
}

String _convertHanziForTrack(
  String text, {
  required String track,
  required String primary,
  required Iterable<VocabEntry> cards,
}) {
  final toTraditional =
      track == 'traditional' || (track == 'both' && primary == 'traditional');
  final map = _hanziVariantMap(toTraditional: toTraditional, cards: cards);
  if (map.isEmpty) return text;
  final buf = StringBuffer();
  for (final r in text.runes) {
    final ch = String.fromCharCode(r);
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}

Map<String, String> _hanziVariantMap({
  required bool toTraditional,
  required Iterable<VocabEntry> cards,
}) {
  final map = <String, String>{};
  for (final c in cards) {
    final s = c.simplified.runes.map(String.fromCharCode).toList();
    final t = c.traditional.runes.map(String.fromCharCode).toList();
    if (s.length != t.length) continue;
    for (var i = 0; i < s.length; i++) {
      if (s[i] == t[i]) continue;
      map[toTraditional ? s[i] : t[i]] = toTraditional ? t[i] : s[i];
    }
  }
  final fallback = toTraditional ? _simpToTrad : _tradToSimp;
  map.addAll(fallback);
  return map;
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
  final PronunciationService pronunciation = PronunciationService();
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
  DateTime? dailyMaterialHiddenUntil;
  int _curriculumRequestSerial = 0;

  // ---- shared session ----
  int qCount = 20;
  List<int> baseCards = [];
  List<int> sessionCards = [];
  List<TestHistoryItem> testHistory = [];
  List<int> aiFocusCardIds = [];
  static const int _maxTestHistory = 80;
  static const int _maxAiFocusCards = 120;
  String? _activeTestHistoryId;
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
  bool pronRecording = false;
  bool pronBusy = false;
  int? pronScore;
  String pronTranscript = '';
  String pronMsg = '';
  List<PronunciationWordScore> pronWords = [];

  String get pronTarget => track == 'traditional' ? '你好' : '你好';

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

    unawaited(fetchDailyMaterial());

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
    final serial = ++_curriculumRequestSerial;
    final requestedTrack = track;
    curriculumLoading = true;
    notifyListeners();
    try {
      final mat = await curriculum.fetch(
        track: requestedTrack,
        level: 'HSK 1-2',
      );
      if (serial != _curriculumRequestSerial) return;
      if (mat != null && requestedTrack == track) {
        dailyMaterial = mat;
        if (_rememberLearningFromText(_dailyMaterialSearchText(mat))) {
          unawaited(_save());
        }
      }
    } finally {
      if (serial == _curriculumRequestSerial) {
        curriculumLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> _loadProfile() async {
    if (!auth.signedIn) return;
    final p = await auth.fetchProfile();
    if (p != null) {
      final oldTrack = track;
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
      await _mergeCloudTestHistory();
      _registerAttendanceToday();
      refreshLeaderboard();
      refreshMyRooms();
      if (track != oldTrack) {
        dailyMaterial = null;
        unawaited(fetchDailyMaterial());
      }
    }
    notifyListeners();
  }

  Future<void> _mergeCloudTestHistory() async {
    final rows = await auth.fetchTestHistory();
    if (rows.isEmpty) return;
    final byId = {for (final h in testHistory) h.id: h};
    for (final row in rows) {
      final incoming = TestHistoryItem.fromJson(row);
      if (incoming.id.isEmpty || incoming.cardIds.isEmpty) continue;
      final old = byId[incoming.id];
      if (old == null || incoming.updatedAt.isAfter(old.updatedAt)) {
        byId[incoming.id] = incoming;
      }
    }
    testHistory = byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    testHistory = testHistory.take(_maxTestHistory).toList();
    await _save();
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
    dailyMaterialHiddenUntil = DateTime.tryParse(
      (j['dailyMaterialHiddenUntil'] as String?) ?? '',
    );
    _nextId = j['nextId'] as int? ?? 0;
    installedPacks
      ..clear()
      ..addAll((j['installedPacks'] as List? ?? []).map((e) => e as String));
    (j['cards'] as Map? ?? {}).forEach((k, v) {
      final id = _parseStoredIntKey(k);
      if (id == null || v is! Map) return;
      cards[id] = VocabEntry.fromJson(Map<String, dynamic>.from(v));
    });
    (j['srs'] as Map? ?? {}).forEach((k, v) {
      final id = _parseStoredIntKey(k);
      if (id == null || v is! Map) return;
      srs[id] = SrsState.fromJson(Map<String, dynamic>.from(v));
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
    testHistory = (j['testHistory'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TestHistoryItem.fromJson(Map<String, dynamic>.from(e)))
        .where((h) => h.id.isNotEmpty && h.cardIds.isNotEmpty)
        .take(_maxTestHistory)
        .toList();
    aiFocusCardIds = (j['aiFocusCardIds'] as List? ?? [])
        .whereType<num>()
        .map((e) => e.toInt())
        .where((id) => cards.containsKey(id))
        .take(_maxAiFocusCards)
        .toList();
    // safety: ensure every card has an srs row
    for (final id in cards.keys) {
      srs.putIfAbsent(id, () => SrsState());
    }
  }

  int? _parseStoredIntKey(Object? key) {
    if (key is int) return key;
    if (key is num) return key.toInt();
    return int.tryParse(key?.toString() ?? '');
  }

  @visibleForTesting
  void restoreForTest(Map<String, dynamic> json) => _restore(json);

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
      'dailyMaterialHiddenUntil': dailyMaterialHiddenUntil?.toIso8601String(),
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
      'testHistory': testHistory
          .take(_maxTestHistory)
          .map((h) => h.toJson())
          .toList(),
      'aiFocusCardIds': aiFocusCardIds.take(_maxAiFocusCards).toList(),
    });
    // Best-effort sync of progress to the cloud profile when signed in.
    if (auth.signedIn) {
      auth.pushStats(xp: xp, streak: streak, lastActiveDate: lastActiveDate);
      unawaited(
        auth.syncTestHistory(testHistory.map((h) => h.toJson()).toList()),
      );
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

  String displayTutorText(String text) => formatTutorReplyForDisplay(
    text,
    track: _zhTrack,
    primary: primary,
    cards: cards.values,
  );

  bool get showDailyMaterialBanner =>
      dailyMaterialHiddenUntil == null ||
      DateTime.now().isAfter(dailyMaterialHiddenUntil!);

  Future<void> snoozeDailyMaterial() async {
    dailyMaterialHiddenUntil = DateTime.now().add(const Duration(hours: 2));
    await _save();
    notifyListeners();
  }

  List<int> smartPracticeBase({int? limit}) {
    final out = <int>[];
    final seen = <int>{};
    void addAll(Iterable<int> ids) {
      for (final id in ids) {
        if (!cards.containsKey(id) || seen.contains(id)) continue;
        seen.add(id);
        out.add(id);
        if (limit != null && out.length >= limit) return;
      }
    }

    Deck? contextDeck = openDeck;
    if (contextDeck == null && _deckCtx != null) {
      for (final deck in decks) {
        if (deck.id == _deckCtx) {
          contextDeck = deck;
          break;
        }
      }
    }
    if (contextDeck != null) addAll(contextDeck.cardIds);
    if (limit != null && out.length >= limit) return out;
    addAll(baseCards);
    if (limit != null && out.length >= limit) return out;

    final mat = dailyMaterial;
    if (mat != null) addAll(_matchingCardIds(_dailyMaterialSearchText(mat)));
    if (limit != null && out.length >= limit) return out;

    addAll(aiFocusCardIds);
    if (limit != null && out.length >= limit) return out;
    addAll(reviewQueue());
    if (limit != null && out.length >= limit) return out;
    addAll(cards.keys);
    return out;
  }

  bool _rememberLearningFromText(String text) {
    final matches = _matchingCardIds(text, limit: 30);
    if (matches.isEmpty) return false;
    final next = <int>[];
    final seen = <int>{};
    for (final id in [...matches, ...aiFocusCardIds]) {
      if (!cards.containsKey(id) || seen.contains(id)) continue;
      seen.add(id);
      next.add(id);
      if (next.length >= _maxAiFocusCards) break;
    }
    if (listEquals(next, aiFocusCardIds)) return false;
    aiFocusCardIds = next;
    return true;
  }

  String _dailyMaterialSearchText(DailyMaterial mat) {
    final vocab = mat.vocab
        .map((v) => '${v.hanzi} ${v.pinyin} ${v.meaning}')
        .join(' ');
    return [
      mat.topic,
      mat.summary,
      vocab,
      ...mat.sentences,
      mat.exercise,
    ].join(' ');
  }

  List<int> _matchingCardIds(String text, {int limit = 80}) {
    final raw = text.toLowerCase();
    final normalized = normalize(raw);
    final out = <int>[];
    for (final entry in cards.entries) {
      final c = entry.value;
      final hanMatch =
          raw.contains(c.simplified) ||
          (c.traditional != c.simplified && raw.contains(c.traditional));
      final pinyin = normalize(c.pinyin);
      final pyMatch = pinyin.isNotEmpty && normalized.contains(pinyin);
      final meaningMatch = VocabEntry.splitMeanings(c.meaning).any((m) {
        final mm = m.toLowerCase().trim();
        return mm.length >= 4 && raw.contains(mm);
      });
      if (hanMatch || pyMatch || meaningMatch) {
        out.add(entry.key);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  /// All card ids that are due or new, due-first — the real FSRS review queue.
  List<int> reviewQueue() {
    final now = DateTime.now();
    final ids = cards.keys.toList();
    for (final id in ids) {
      srs.putIfAbsent(id, () => SrsState());
    }
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
    Deck? contextDeck = openDeck;
    if (contextDeck == null && _deckCtx != null) {
      for (final deck in decks) {
        if (deck.id == _deckCtx) {
          contextDeck = deck;
          break;
        }
      }
    }
    final source =
        contextDeck?.cardIds ?? (baseCards.isEmpty ? cards.keys : baseCards);
    final ids = source.where((id) => cards.containsKey(id)).toSet();
    return ids.length;
  }

  String get questionLimitLabel {
    final max = currentQuestionMax;
    if (max == 0) return 'Belum ada kartu di deck ini';
    return 'Kelipatan 10 · maksimal $max sesuai deck';
  }

  int get _questionFloor => math.min(10, currentQuestionMax);

  void _clampQCount() {
    final max = currentQuestionMax;
    qCount = qCount.clamp(_questionFloor, max);
  }

  List<int> makeSession(List<int> base, int n) {
    final inDeckContext = openDeck != null || _deckCtx != null;
    final source = base.isEmpty && !inDeckContext ? cards.keys.toList() : base;
    final b = List<int>.of(
      source,
    ).where((id) => cards.containsKey(id)).toSet().toList();
    if (b.isEmpty) return [];
    b.shuffle(rng);
    return b.take(math.min(n, b.length)).toList();
  }

  List<String> _makeOptions(int cardId, {String? direction}) {
    final dir = direction ?? testDirection;
    if (dir == 'id2zh') {
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

  List<QuizItem> _buildQuiz(List<int> ids, {String? direction}) {
    final dir = direction ?? testDirection;
    if (dir == 'id2zh') {
      return ids
          .map(
            (id) => QuizItem(
              cardId: id,
              correct: primaryHanzi(card(id)),
              options: _makeOptions(id, direction: dir),
            ),
          )
          .toList();
    }
    return ids
        .map(
          (id) => QuizItem(
            cardId: id,
            correct: card(id).primaryMeaning,
            options: _makeOptions(id, direction: dir),
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
    closeRoomChannel(notify: false);
    leaderOpen = false;
    adding = false;
    notifyListeners();
  }

  bool handleBack() {
    if (leaderOpen) {
      closeLeader();
      return true;
    }
    if (tab == 'chat' && chatTab == 'grup' && currentRoom != null) {
      closeRoomChannel();
      return true;
    }
    if (sub != null) {
      closeSub();
      return true;
    }
    if (tab != 'beranda') {
      go('beranda');
      return true;
    }
    return false;
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
    closeRoomChannel(notify: false);
    currentRoom = room;
    roomMsgs = [];
    roomOnline = 0;
    roomLoading = true;
    notifyListeners();
    roomMsgs = await rooms.history(room.id);
    var learnedFromHistory = false;
    for (final m in roomMsgs) {
      learnedFromHistory =
          _rememberLearningFromText(m.body) || learnedFromHistory;
    }
    if (learnedFromHistory) unawaited(_save());
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
        if (_rememberLearningFromText(m.body)) unawaited(_save());
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
  void closeRoomChannel({bool notify = true}) {
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
    if (notify) notifyListeners();
  }

  /// Leaves the room (drops membership) and returns to the room list.
  Future<void> leaveCurrentRoom() async {
    final r = currentRoom;
    if (r == null) return;
    await rooms.leaveRoom(r.id);
    closeRoomChannel(notify: false);
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
    if (track == t) return;
    track = t;
    if (t != 'both') primary = t;
    dailyMaterial = null;
    notifyListeners();
    _save();
    unawaited(fetchDailyMaterial());
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

  Deck? get openDeck {
    final id = openDeckId;
    if (id == null) return null;
    final matches = decks.where((d) => d.id == id).toList();
    return matches.isEmpty ? null : matches.first;
  }

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
    baseCards = List.of(d.cardIds);
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

  bool get hasActiveTestInProgress {
    if (_activeTestHistoryId == null) return false;
    if (sub != 'quiz' && sub != 'review' && sub != 'spell') return false;
    final h = _activeTestHistory;
    if (h == null || h.completed) return false;
    if (h.mode == 'self') {
      return reviewMode == 'self' && reviewIdx < sessionCards.length;
    }
    if (h.mode == 'mc') return quizIdx < quizTotal;
    if (h.mode == 'spell') return spellIdx < sessionCards.length;
    return false;
  }

  TestHistoryItem? get _activeTestHistory {
    final id = _activeTestHistoryId;
    if (id == null) return null;
    for (final h in testHistory) {
      if (h.id == id) return h;
    }
    return null;
  }

  String get _testTitle {
    final d = openDeck;
    if (d != null) return d.name;
    if (_deckCtx != null) {
      final matches = decks.where((deck) => deck.id == _deckCtx).toList();
      if (matches.isNotEmpty) return matches.first.name;
    }
    return 'Tes ${sessionCards.length} kartu';
  }

  void _upsertTestHistory(TestHistoryItem item) {
    testHistory = [
      item,
      ...testHistory.where((h) => h.id != item.id),
    ].take(_maxTestHistory).toList();
  }

  void _beginTestHistory(String mode) {
    final now = DateTime.now();
    final id = 'test_${now.microsecondsSinceEpoch}_${rng.nextInt(9999)}';
    _activeTestHistoryId = id;
    _upsertTestHistory(
      TestHistoryItem(
        id: id,
        mode: mode,
        title: _testTitle,
        deckId: openDeckId ?? _deckCtx,
        direction: testDirection,
        cardIds: List<int>.of(sessionCards),
        index: 0,
        score: 0,
        startedAt: now,
        updatedAt: now,
      ),
    );
    _save();
  }

  void _updateActiveTestHistory({bool completed = false}) {
    final h = _activeTestHistory;
    if (h == null) return;
    final mode = h.mode;
    final index = switch (mode) {
      'self' => reviewIdx,
      'spell' => spellIdx,
      _ => quizIdx,
    };
    final score = switch (mode) {
      'self' => reviewScore,
      'spell' => spellScore,
      _ => quizScore,
    };
    final done = completed || index >= sessionCards.length;
    _upsertTestHistory(
      h.copyWith(
        direction: testDirection,
        cardIds: List<int>.of(sessionCards),
        index: index,
        score: score,
        picked: mode == 'mc' ? quizPicked : null,
        spellInput: spellInput,
        spellChecked: spellChecked,
        spellCorrect: spellCorrect,
        flipped: flipped,
        completed: done,
        updatedAt: DateTime.now(),
      ),
    );
    if (done) _activeTestHistoryId = null;
    _save();
  }

  void abandonActiveTestToHistory() {
    _updateActiveTestHistory();
    _activeTestHistoryId = null;
  }

  void resumeTestHistory(TestHistoryItem item) {
    final ids = item.cardIds.where((id) => cards.containsKey(id)).toList();
    if (ids.isEmpty) return;
    _activeTestHistoryId = item.id;
    sessionCards = ids;
    baseCards = ids;
    testDirection = item.direction;
    openDeckId = item.deckId;
    _deckCtx = item.deckId;
    qCount = ids.length;
    switch (item.mode) {
      case 'self':
        reviewMode = 'self';
        reviewIdx = item.index.clamp(0, ids.length);
        reviewScore = item.score;
        flipped = item.flipped;
        sub = 'review';
        break;
      case 'spell':
        spellIdx = item.index.clamp(0, ids.length);
        spellScore = item.score;
        spellInput = item.spellInput;
        spellChecked = item.spellChecked;
        spellCorrect = item.spellCorrect;
        sub = 'spell';
        break;
      case 'mc':
      default:
        _quiz = _buildQuiz(sessionCards);
        quizIdx = item.index.clamp(0, ids.length);
        quizScore = item.score;
        quizPicked = item.picked;
        sub = 'quiz';
        break;
    }
    notifyListeners();
  }

  void startReview(List<int> ids, String mode) {
    sessionCards = ids.isEmpty ? makeSession(baseCards, qCount) : List.of(ids);
    if (sessionCards.isEmpty) {
      reviewIdx = 0;
      flipped = false;
      reviewScore = 0;
      notifyListeners();
      return;
    }
    reviewMode = mode;
    sub = 'review';
    reviewIdx = 0;
    flipped = false;
    reviewScore = 0;
    if (mode == 'self') _beginTestHistory('self');
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
        _updateActiveTestHistory(completed: true);
      }
    } else if (reviewMode == 'self') {
      _updateActiveTestHistory();
    }
    _save();
    notifyListeners();
  }

  // ===========================================================================
  // TEST PICKER + MODES
  // ===========================================================================

  void goTestPick({List<int>? base}) {
    baseCards = base ?? smartPracticeBase();
    openDeckId = null;
    _deckCtx = null;
    _clampQCount();
    sub = 'testpick';
    notifyListeners();
  }

  void goDailyTest() => goTestPick(base: smartPracticeBase());

  void toggleTestDirection() {
    testDirection = testDirection == 'zh2id' ? 'id2zh' : 'zh2id';
    notifyListeners();
  }

  void startMc() {
    sessionCards = makeSession(baseCards, qCount);
    if (sessionCards.isEmpty) {
      _quiz = [];
      quizIdx = 0;
      quizScore = 0;
      quizPicked = null;
      notifyListeners();
      return;
    }
    _quiz = _buildQuiz(sessionCards);
    sub = 'quiz';
    quizIdx = 0;
    quizScore = 0;
    quizPicked = null;
    _beginTestHistory('mc');
    notifyListeners();
  }

  void startSelf() => startReview(makeSession(baseCards, qCount), 'self');

  void startSpell() {
    sessionCards = makeSession(baseCards, qCount);
    if (sessionCards.isEmpty) {
      spellIdx = 0;
      spellInput = '';
      spellChecked = false;
      spellCorrect = false;
      spellScore = 0;
      notifyListeners();
      return;
    }
    sub = 'spell';
    spellIdx = 0;
    spellInput = '';
    spellChecked = false;
    spellCorrect = false;
    spellScore = 0;
    _beginTestHistory('spell');
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
    _updateActiveTestHistory();
    notifyListeners();
  }

  void nextQuiz() {
    quizIdx++;
    quizPicked = null;
    if (quizIdx >= quizTotal) {
      lastTestPct = ((quizScore / quizTotal) * 100).round();
      xp += quizScore;
      _updateActiveTestHistory(completed: true);
      _save();
    } else {
      _updateActiveTestHistory();
    }
    notifyListeners();
  }

  void restartQuiz() {
    _quiz = _buildQuiz(sessionCards);
    quizIdx = 0;
    quizScore = 0;
    quizPicked = null;
    _beginTestHistory('mc');
    notifyListeners();
  }

  // Spelling
  int get spellCardId =>
      sessionCards[math.min(spellIdx, sessionCards.length - 1)];

  void setSpellInput(String v) {
    spellInput = v;
    _updateActiveTestHistory();
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
    _updateActiveTestHistory();
    notifyListeners();
  }

  void nextSpell() {
    spellIdx++;
    spellInput = '';
    spellChecked = false;
    spellCorrect = false;
    if (spellIdx >= sessionCards.length) {
      lastTestPct = ((spellScore / sessionCards.length) * 100).round();
      _updateActiveTestHistory(completed: true);
      _save();
    } else {
      _updateActiveTestHistory();
    }
    notifyListeners();
  }

  void restartSpell() {
    spellIdx = 0;
    spellInput = '';
    spellChecked = false;
    spellCorrect = false;
    spellScore = 0;
    _beginTestHistory('spell');
    notifyListeners();
  }

  // ===========================================================================
  // GAMES HUB
  // ===========================================================================

  void goGames() {
    _speedTimer?.cancel();
    recording = false;
    baseCards = smartPracticeBase();
    _clampQCount();
    sub = 'games';
    notifyListeners();
  }

  // Tone
  ({String han, String pinyin, int tone}) get toneCur {
    if (sessionCards.isNotEmpty) {
      final id = sessionCards[toneIdx % sessionCards.length];
      final c = card(id);
      return (han: primaryHanzi(c), pinyin: c.pinyin, tone: c.tone);
    }
    return toneBank[toneIdx % toneBank.length];
  }

  int get toneTotal => qCount;

  void startTone() {
    baseCards = smartPracticeBase();
    _clampQCount();
    sessionCards = makeSession(baseCards, qCount);
    if (sessionCards.isEmpty) {
      toneIdx = 0;
      toneScore = 0;
      tonePicked = null;
      notifyListeners();
      return;
    }
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
    final cur = toneCur;
    final correct = n == cur.tone;
    tonePicked = n;
    if (correct) toneScore++;
    if (sessionCards.isNotEmpty) {
      final id = sessionCards[toneIdx % sessionCards.length];
      _recordPractice(id, correct, xpCorrect: 0, xpWrong: 0);
    }
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
    baseCards = smartPracticeBase();
    _clampQCount();
    var base = {
      ...(baseCards.isEmpty ? cards.keys.take(6) : baseCards),
    }.toList();
    if (base.length < 4) base = cards.keys.take(6).toList();
    _matchPairs = base.take(6).toList();
    if (_matchPairs.isEmpty) {
      _matchTiles = [];
      matchMatched = [];
      matchSel = null;
      matchWrong = [];
      matchMoves = 0;
      notifyListeners();
      return;
    }
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
    baseCards = smartPracticeBase();
    _clampQCount();
    sessionCards = makeSession(baseCards, qCount);
    if (sessionCards.isEmpty) {
      _quiz = [];
      quizIdx = 0;
      quizScore = 0;
      quizPicked = null;
      notifyListeners();
      return;
    }
    _quiz = _buildQuiz(sessionCards, direction: 'zh2id');
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
    baseCards = smartPracticeBase();
    _clampQCount();
    sessionCards = makeSession(baseCards, qCount);
    if (sessionCards.isEmpty) {
      _speedTimer?.cancel();
      _speed = [];
      speedIdx = 0;
      speedScore = 0;
      speedLeft = 45;
      notifyListeners();
      return;
    }
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

  Future<void> togglePronunciationAssessment() async {
    if (pronBusy) return;
    if (pronRecording) {
      pronRecording = false;
      pronBusy = true;
      pronMsg = 'Menganalisis pelafalan...';
      notifyListeners();
      final result = await pronunciation.stopAndScore(
        referenceText: pronTarget,
        lang: 'zh',
      );
      pronBusy = false;
      if (result == null) {
        pronScore = null;
        pronTranscript = '';
        pronWords = [];
        pronMsg = pronunciation.lastError ?? 'Skor pelafalan belum tersedia.';
      } else {
        pronScore = result.score;
        pronTranscript = result.transcript;
        pronWords = result.words;
        pronMsg = _pronVerdict(result.score);
        xp += result.score >= 75 ? 2 : 1;
        await _save();
      }
      notifyListeners();
      return;
    }

    if (recording) {
      recording = false;
      micLevel = 0;
      tunerMatch = 0;
      await _pitch.stop();
    }
    if (micList.isEmpty) await loadMics();
    pronScore = null;
    pronTranscript = '';
    pronWords = [];
    pronMsg = 'Ucapkan $pronTarget dengan jelas, lalu tekan selesai.';
    pronRecording = await pronunciation.start(device: micDevice);
    if (!pronRecording) {
      pronMsg = pronunciation.lastError ?? 'Mikrofon tidak tersedia.';
    }
    notifyListeners();
  }

  String _pronVerdict(int score) {
    if (score >= 90) return 'Sangat jelas. Pertahankan ritme dan nada.';
    if (score >= 75) return 'Bagus. Tinggal rapikan nada dan artikulasi.';
    if (score >= 55) return 'Cukup terdengar. Ulangi lebih pelan dan jelas.';
    return 'Belum kebaca jelas. Dekatkan mic dan ucapkan perlahan.';
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
      _trSeq++;
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
    _trSeq++;
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
    _trSeq++;
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
    _rememberLearningFromText(txt);
    chatInput = '';
    tutorTyping = true;
    notifyListeners();

    String? reply;
    try {
      reply = await llm
          .chat(buildGroundedHistory(_llmHistory(), idiomBank), track: _zhTrack)
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
    reply = displayTutorText(reply);
    messages = [...messages, ChatMsg('t', reply)];
    _rememberLearningFromText(reply);
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
    _rememberLearningFromText(
      '${it.simplified} ${it.traditional} ${it.meaning}',
    );
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
      reply = await llm.chat(hist, track: _zhTrack);
    }
    reply ??=
        'Idiom ${it.simplified} (${it.pinyin}) — ${it.meaning}.'
        '${it.literal.isNotEmpty ? ' Harfiah: ${it.literal}.' : ''}';
    tutorTyping = false;
    reply = displayTutorText(reply);
    messages = [...messages, ChatMsg('t', reply)];
    _rememberLearningFromText(reply);
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
    final learned = _rememberLearningFromText(txt);
    final callGuru = mentionsGuru(txt);
    if (callGuru) roomGuruBusy = true;
    notifyListeners();

    final sent = await rooms.sendMessage(
      r.id,
      body: txt,
      authorName: me,
      authorHandle: profileHandle,
    );
    if (!sent) {
      roomMsgs = roomMsgs
          .where((m) => !(m.id == 0 && m.isMine(authUid) && m.body == txt))
          .toList();
      if (callGuru) roomGuruBusy = false;
      notifyListeners();
      return;
    }
    if (callGuru) {
      final err = await rooms.callGuru(r.id, track: _zhTrack);
      if (err != null) {
        roomGuruBusy = false;
        notifyListeners();
      }
    }
    if (learned) unawaited(_save());
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

  /// Feeds each final-exam answer back into the same mastery engine as deck
  /// tests/games, without double-counting exam XP.
  void recordUjianAkhirAnswer(int cardId, bool correct) {
    _recordPractice(cardId, correct, xpCorrect: 0, xpWrong: 0);
    unawaited(_save());
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
    closeRoomChannel(notify: false);
    pronunciation.cancel();
    _pitch.dispose();
    super.dispose();
  }
}
