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
      if (s.contains('profiles_handle') || s.contains('duplicate')) {
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
      return ZwsProfile(
        handle: (row['handle'] as String?) ?? '',
        publicId: (row['public_id'] as num?)?.toInt() ?? 0,
        displayName: (row['display_name'] as String?) ?? '',
        track: (row['track'] as String?) ?? 'both',
        xp: (row['xp'] as num?)?.toInt() ?? 0,
        streak: (row['streak'] as num?)?.toInt() ?? 0,
        avatarUrl: row['avatar_url'] as String?,
        lastActiveDate: row['last_active_date']?.toString(),
      );
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
      if (s.contains('profiles_handle') || s.contains('duplicate')) {
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
      return (rows as List).cast<Map<String, dynamic>>();
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
      return (rows as List)
          .map((row) => Map<String, dynamic>.from(row['payload'] as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> syncTestHistory(List<Map<String, dynamic>> history) async {
    final id = uid;
    if (id == null || history.isEmpty) return;
    try {
      final rows = history.take(80).map((h) {
        final updatedAt =
            (h['updatedAt'] as String?) ?? DateTime.now().toIso8601String();
        return {
          'id': h['id'],
          'user_id': id,
          'payload': h,
          'updated_at': updatedAt,
        };
      }).toList();
      await _sb.from('test_history').upsert(rows, onConflict: 'id,user_id');
    } catch (_) {
      // Best-effort cloud history. Local history remains the source of truth.
    }
  }
}
