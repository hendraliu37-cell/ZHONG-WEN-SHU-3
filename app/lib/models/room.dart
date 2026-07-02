// Models + pure helpers for the realtime study rooms (Grup / M3).
//
// Kept free of Flutter/Supabase imports so the parsing and `@Guru`-detection
// logic can be unit-tested without a backend or widget tree.

/// A study room the user belongs to.
class Room {
  final String id;
  final String code; // invite code, e.g. 'ZWS-7F3KQ'
  final String name;
  final String levelTag;
  final String owner; // owner user id
  final int memberCount;

  const Room({
    required this.id,
    required this.code,
    required this.name,
    this.levelTag = '',
    this.owner = '',
    this.memberCount = 0,
  });

  factory Room.fromJson(Map j, {int memberCount = 0}) => Room(
    id: (j['id'] ?? '').toString(),
    code: (j['code'] ?? '').toString(),
    name: (j['name'] ?? 'Ruang').toString(),
    levelTag: (j['level_tag'] ?? '').toString(),
    owner: (j['owner'] ?? '').toString(),
    memberCount: memberCount,
  );

  Room copyWith({int? memberCount}) => Room(
    id: id,
    code: code,
    name: name,
    levelTag: levelTag,
    owner: owner,
    memberCount: memberCount ?? this.memberCount,
  );
}

/// A single message in a room. `senderId == null` && `isGuru` ⇒ the AI tutor.
class RoomMessage {
  final int id; // 0 for optimistic local echoes not yet round-tripped
  final String? senderId;
  final String authorName;
  final String authorHandle;
  final bool isGuru;
  final String body;
  final DateTime createdAt;

  const RoomMessage({
    required this.id,
    required this.senderId,
    required this.authorName,
    this.authorHandle = '',
    this.isGuru = false,
    required this.body,
    required this.createdAt,
  });

  factory RoomMessage.fromJson(Map j) => RoomMessage(
    id: _intish(j['id']) ?? 0,
    senderId: _nullableString(j['sender_id']),
    authorName: _stringish(j['author_name']),
    authorHandle: _stringish(j['author_handle']),
    isGuru: _boolish(j['is_guru']),
    body: _stringish(j['body']),
    createdAt:
        DateTime.tryParse(_stringish(j['created_at']))?.toLocal() ??
        DateTime.now(),
  );

  /// True when this message was sent by [uid] (the local user).
  bool isMine(String? uid) => uid != null && senderId == uid;
}

String _stringish(Object? value) => value?.toString().trim() ?? '';

String? _nullableString(Object? value) {
  final text = _stringish(value);
  return text.isEmpty ? null : text;
}

int? _intish(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  final text = _stringish(value);
  if (text.isEmpty) return null;
  return int.tryParse(text) ?? double.tryParse(text)?.toInt();
}

bool _boolish(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = _stringish(value).toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}

/// True if [text] calls the tutor with an `@Guru` mention (case-insensitive),
/// requiring a word boundary so "@gurun" or an email-like "x@guru.com" don't
/// trigger it.
bool mentionsGuru(String text) {
  return RegExp(
    r'(^|[^\w@＠])[@＠]guru($|[^\w.])',
    caseSensitive: false,
  ).hasMatch(text);
}

/// True while the user is typing a Guru mention token (`@`, `@g`, `＠gu`, ...).
/// Accepts fullwidth `＠` because Chinese keyboards can emit it.
bool isGuruMentionPrefix(String token) {
  final normalized = token.replaceFirst('＠', '@').toLowerCase();
  return normalized == '@' ||
      (normalized.startsWith('@') && '@guru'.startsWith(normalized));
}

/// Replaces the mention token around [caret] with `@Guru `.
({String text, int caret}) insertGuruMention(String text, int caret) {
  final safeCaret = caret < 0 ? text.length : caret.clamp(0, text.length);
  final before = text.substring(0, safeCaret);
  final after = text.substring(safeCaret);
  final start = before.lastIndexOf(RegExp(r'\s'));
  final tokenStart = start < 0 ? 0 : start + 1;
  final nextText = '${before.substring(0, tokenStart)}@Guru $after'.replaceAll(
    RegExp(r' {2,}'),
    ' ',
  );
  final nextCaret = (tokenStart + 6).clamp(0, nextText.length).toInt();
  return (text: nextText, caret: nextCaret);
}

/// Normalizes a typed invite code to canonical form (`ZWS-XXXXX`, uppercase).
/// Accepts input with or without the `ZWS-` prefix and stray spaces/dashes.
String normalizeRoomCode(String input) {
  var s = input.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
  s = s.replaceAll('ZWS-', '').replaceAll('-', '');
  return s.isEmpty ? '' : 'ZWS-$s';
}

/// True if [code] looks like a well-formed invite code: `ZWS-` + 5 base32
/// chars from the unambiguous alphabet used by `gen_room_code()`.
bool isValidRoomCode(String code) =>
    RegExp(r'^ZWS-[2-9A-HJ-NP-Z]{5}$').hasMatch(code);

/// User-facing copy for local-only room failures. Kept in the model layer so
/// the room UX can be regression-tested without a Supabase connection.
String roomSendFailureMessage() =>
    'Pesan belum terkirim. Cek koneksi, lalu coba kirim lagi.';

/// User-facing copy when the group tutor Edge Function could not reply.
String roomGuruFailureMessage(String? code) {
  switch (code) {
    case 'offline':
      return 'Guru belum bisa dipanggil karena kamu sedang offline atau belum masuk.';
    case 'llm_not_configured':
    case 'not_configured':
      return 'Guru belum siap di server. Coba lagi nanti setelah konfigurasi AI aktif.';
    case 'unauthorized':
    case 'no_auth':
      return 'Guru butuh sesi login yang aktif. Masuk ulang, lalu coba lagi.';
    case 'not_member':
      return 'Guru hanya bisa menjawab di ruang yang masih kamu ikuti.';
    case 'llm_failed':
    case 'failed':
      return 'Guru belum berhasil menjawab. Coba ulang sebentar lagi.';
    case 'insert_failed':
      return 'Jawaban Guru sudah dibuat, tapi belum bisa disimpan ke ruang.';
    default:
      return 'Guru belum tersedia. Coba ulang sebentar lagi.';
  }
}
