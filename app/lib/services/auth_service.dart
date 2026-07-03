import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// A user's public profile (handle + numeric id + track), loaded from the
/// `profiles` table after sign-in.
class ZwsProfile {
  final String handle;
  final int publicId;
  final String displayName;
  final String track;
  final int xp;
  final int streak;
  final String? avatarUrl;
  final String? lastActiveDate;
  const ZwsProfile({
    required this.handle,
    required this.publicId,
    required this.displayName,
    required this.track,
    this.xp = 0,
    this.streak = 0,
    this.avatarUrl,
    this.lastActiveDate,
  });
}

/// Thin wrapper over Supabase Auth. Every method is a no-op / null unless the
/// backend was initialized in `main()` (`zwsSupabaseReady`), so the app degrades
/// gracefully to offline guest mode when there is no backend (e.g. in tests).
class AuthService {
  bool get enabled => zwsSupabaseReady;

  SupabaseClient get _sb => Supabase.instance.client;

  Session? get session => enabled ? _sb.auth.currentSession : null;
  bool get signedIn => session != null;
  String? get uid => enabled ? _sb.auth.currentUser?.id : null;

  Stream<AuthState> get onAuthChange => _sb.auth.onAuthStateChange;

  String _friendlyAuthError(Object error) {
    final raw = error is AuthException ? error.message : error.toString();
    final msg = raw.toLowerCase();
    if (_looksLikeHandleTaken(msg)) return 'Username sudah dipakai.';
    if (msg.contains('email rate limit') ||
        msg.contains('rate limit') ||
        msg.contains('rate_limit') ||
        msg.contains('too many') ||
        msg.contains('over email send rate limit') ||
        msg.contains('over_email_send_rate_limit') ||
        msg.contains('email address rate limit') ||
        msg.contains('email address rate limit exceeded') ||
        msg.contains('security purposes') ||
        msg.contains('request this after')) {
      return 'Batas kirim email tercapai. Tunggu beberapa menit dulu, lalu coba lagi. Kalau akun sudah dibuat, langsung coba masuk tanpa daftar ulang.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox/spam, lalu buka link konfirmasi sebelum masuk.';
    }
    if (msg.contains('invalid login credentials')) {
      return 'Email atau kata sandi salah.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already registered') ||
        msg.contains('already exists')) {
      return 'Email ini sudah terdaftar. Coba masuk saja.';
    }
    return raw;
  }

  bool _looksLikeHandleTaken(String msg) =>
      msg.contains('profiles_handle') ||
      msg.contains('handle_idx') ||
      (msg.contains('23505') && msg.contains('handle')) ||
      (msg.contains('unique constraint') && msg.contains('handle'));

  @visibleForTesting
  String friendlyAuthErrorForTest(Object error) => _friendlyAuthError(error);

  /// True if [handle] is not yet taken. Falls back to `true` on any error so a
  /// transient check failure never blocks registration (the unique constraint
  /// is the real guard).
  Future<bool> handleAvailable(String handle) async {
    try {
      final res = await _sb.rpc(
        'handle_available',
        params: {'p_handle': handle},
      );
      return res != false;
    } catch (_) {
      return true;
    }
  }

  /// Returns null on success, or a human-readable error message.
  Future<String?> signUp({
    required String email,
    required String password,
    required String handle,
    required String displayName,
    required String track,
  }) async {
    try {
      await _sb.auth.signUp(
        email: email,
        password: password,
        data: {
          'handle': handle.toLowerCase(),
          'display_name': displayName,
          'track': track,
        },
      );
      return null;
    } on AuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      // The signup trigger raises a unique-violation if the handle is taken.
      final s = e.toString();
      final lower = s.toLowerCase();
      if (_looksLikeHandleTaken(lower) || lower.contains('duplicate')) {
        return 'Username sudah dipakai.';
      }
      return _friendlyAuthError(e);
    }
  }

  /// Returns null on success, or a human-readable error message.
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _sb.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (e) {
      return _friendlyAuthError(e);
    } catch (e) {
      return _friendlyAuthError(e);
    }
  }

  Future<void> signOut() async {
    if (enabled) await _sb.auth.signOut();
  }

  Future<void> updateTrack(String track) async {
    final id = uid;
    if (id == null) return;
    try {
      await _sb.from('profiles').update({'track': track}).eq('id', id);
    } catch (_) {
      /* best-effort */
    }
  }

  Future<ZwsProfile?> fetchProfile() async {
    final id = uid;
    if (id == null) return null;
    try {
      final row = await _sb
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return _parseProfileRow(row);
    } catch (_) {
      return null;
    }
  }

  Future<void> pushStats({
    required int xp,
    required int streak,
    String? lastActiveDate,
  }) async {
    final id = uid;
    if (id == null) return;
    try {
      await _sb
          .from('profiles')
          .update({
            'xp': xp,
            'streak': streak,
            'last_active_date': lastActiveDate,
          })
          .eq('id', id);
    } catch (_) {
      /* best-effort */
    }
  }

  /// Updates the username (handle). Returns null on success or an error message.
  Future<String?> updateUsername(String handle) async {
    final id = uid;
    if (id == null) return 'Belum masuk.';
    try {
      await _sb
          .from('profiles')
          .update({'handle': handle.toLowerCase()})
          .eq('id', id);
      return null;
    } catch (e) {
      final s = e.toString();
      final lower = s.toLowerCase();
      if (_looksLikeHandleTaken(lower) || lower.contains('duplicate')) {
        return 'Username sudah dipakai.';
      }
      return s;
    }
  }

  Future<void> updateAvatarUrl(String? url) async {
    final id = uid;
    if (id == null) return;
    try {
      await _sb.from('profiles').update({'avatar_url': url}).eq('id', id);
    } catch (_) {
      /* best-effort */
    }
  }

  /// Uploads an avatar image and returns its public URL (or null on failure).
  Future<String?> uploadAvatar(Uint8List bytes, String ext) async {
    final id = uid;
    if (id == null) return null;
    try {
      final e = (ext == 'jpg') ? 'jpeg' : ext;
      final path = '$id/avatar.$e';
      await _sb.storage
          .from('avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(upsert: true, contentType: 'image/$e'),
          );
      final base = _sb.storage.from('avatars').getPublicUrl(path);
      final url = '$base?v=${DateTime.now().millisecondsSinceEpoch}';
      await _sb.from('profiles').update({'avatar_url': url}).eq('id', id);
      return url;
    } catch (_) {
      return null;
    }
  }

  /// Global leaderboard rows (handle, public_id, xp) ordered by xp desc.
  Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 50}) async {
    try {
      final rows = await _sb
          .from('profiles')
          .select('handle, display_name, public_id, xp')
          .order('xp', ascending: false)
          .limit(limit);
      return _parseLeaderboardRows(rows);
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchTestHistory() async {
    final id = uid;
    if (id == null) return [];
    try {
      final rows = await _sb
          .from('test_history')
          .select('payload')
          .eq('user_id', id)
          .order('updated_at', ascending: false)
          .limit(80);
      return _parseTestHistoryRows(rows);
    } catch (_) {
      return [];
    }
  }

  Future<void> syncTestHistory(List<Map<String, dynamic>> history) async {
    final id = uid;
    if (id == null || history.isEmpty) return;
    try {
      final rows = _testHistorySyncRows(
        history,
        userId: id,
        fallbackUpdatedAt: DateTime.now().toIso8601String(),
      );
      if (rows.isEmpty) return;
      await _sb.from('test_history').upsert(rows, onConflict: 'id,user_id');
    } catch (_) {
      // Best-effort cloud history. Local history remains the source of truth.
    }
  }
}

ZwsProfile _parseProfileRow(Map row) {
  final track = _oneOf(row['track'], const {
    'simplified',
    'traditional',
    'both',
  }, fallback: 'both');
  return ZwsProfile(
    handle: _stringish(row['handle']),
    publicId: _intish(row['public_id']) ?? 0,
    displayName: _stringish(row['display_name']),
    track: track,
    xp: _intish(row['xp'], min: 0) ?? 0,
    streak: _intish(row['streak'], min: 0) ?? 0,
    avatarUrl: _nullableString(row['avatar_url']),
    lastActiveDate: _nullableString(row['last_active_date']),
  );
}

List<Map<String, dynamic>> _parseLeaderboardRows(Object? rows) {
  final out = <Map<String, dynamic>>[];
  if (rows is! List) return out;
  for (final row in rows) {
    if (row is! Map) continue;
    out.add({
      'handle': _stringish(row['handle']),
      'display_name': _stringish(row['display_name']),
      'public_id': _intish(row['public_id']) ?? 0,
      'xp': _intish(row['xp'], min: 0) ?? 0,
    });
  }
  return out;
}

List<Map<String, dynamic>> _parseTestHistoryRows(Object? rows) {
  final out = <Map<String, dynamic>>[];
  if (rows is! List) return out;
  for (final row in rows) {
    if (row is! Map) continue;
    final payload = _jsonObject(row['payload']);
    if (payload == null) continue;
    if (_stringish(payload['id']).isEmpty) continue;
    out.add(Map<String, dynamic>.from(payload));
  }
  return out;
}

List<Map<String, dynamic>> _testHistorySyncRows(
  List<Map<String, dynamic>> history, {
  required String userId,
  required String fallbackUpdatedAt,
}) {
  final out = <Map<String, dynamic>>[];
  for (final h in history.take(80)) {
    final id = _stringish(h['id']);
    if (id.isEmpty) continue;
    out.add({
      'id': id,
      'user_id': userId,
      'payload': h,
      'updated_at': _isoTimestamp(h['updatedAt'], fallbackUpdatedAt),
    });
  }
  return out;
}

String _isoTimestamp(Object? value, String fallback) {
  if (value is DateTime) return value.toIso8601String();
  final text = _stringish(value);
  final numeric = value is num
      ? value
      : (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(text) ? num.tryParse(text) : null);
  if (numeric != null) {
    final raw = numeric.toInt();
    final ms = raw.abs() >= 100000000000 ? raw : raw * 1000;
    return DateTime.fromMillisecondsSinceEpoch(
      ms,
      isUtc: true,
    ).toIso8601String();
  }
  final parsed = DateTime.tryParse(text);
  return parsed?.toIso8601String() ?? fallback;
}

Map<dynamic, dynamic>? _jsonObject(Object? data) {
  if (data is Map) return data;
  if (data is String) {
    final text = data.trim();
    if (!text.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map ? decoded : null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

String _stringish(Object? value) => value?.toString().trim() ?? '';

String? _nullableString(Object? value) {
  final text = _stringish(value);
  return text.isEmpty ? null : text;
}

int? _intish(Object? value, {int? min}) {
  int? parsed;
  if (value is int) {
    parsed = value;
  } else if (value is num) {
    parsed = value.toInt();
  } else {
    final text = _stringish(value);
    parsed = int.tryParse(text) ?? double.tryParse(text)?.toInt();
  }
  if (parsed == null) return null;
  if (min != null && parsed < min) return min;
  return parsed;
}

String _oneOf(Object? value, Set<String> allowed, {required String fallback}) {
  final text = _stringish(value);
  return allowed.contains(text) ? text : fallback;
}

@visibleForTesting
List<Map<String, dynamic>> parseTestHistoryRowsForTest(Object? rows) =>
    _parseTestHistoryRows(rows);

@visibleForTesting
List<Map<String, dynamic>> testHistorySyncRowsForTest(
  List<Map<String, dynamic>> history, {
  required String userId,
  required String fallbackUpdatedAt,
}) => _testHistorySyncRows(
  history,
  userId: userId,
  fallbackUpdatedAt: fallbackUpdatedAt,
);

@visibleForTesting
ZwsProfile parseProfileRowForTest(Map row) => _parseProfileRow(row);

@visibleForTesting
List<Map<String, dynamic>> parseLeaderboardRowsForTest(Object? rows) =>
    _parseLeaderboardRows(rows);
