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
    id: (j['id'] is num) ? (j['id'] as num).toInt() : 0,
    senderId: j['sender_id']?.toString(),
    authorName: (j['author_name'] ?? '').toString(),
    authorHandle: (j['author_handle'] ?? '').toString(),
    isGuru: j['is_guru'] == true,
    body: (j['body'] ?? '').toString(),
    createdAt:
        DateTime.tryParse((j['created_at'] ?? '').toString())?.toLocal() ??
        DateTime.now(),
  );

  /// True when this message was sent by [uid] (the local user).
  bool isMine(String? uid) => uid != null && senderId == uid;
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
