import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/room.dart';

/// Backend for the realtime study rooms (Grup / M3). Wraps Supabase: room CRUD
/// via security-definer RPCs (`create_room`/`join_room`), message history +
/// insert, the `group-guru` Edge Function for `@Guru`, and a Realtime channel
/// (postgres_changes for new messages + Presence for the online roster).
///
/// Every call no-ops / returns empty when the backend is absent
/// (`zwsSupabaseReady` false in guest mode and widget tests), so the app never
/// crashes offline.
class RoomService {
  bool get enabled => zwsSupabaseReady;
  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;

  /// Rooms the signed-in user belongs to, with member counts.
  Future<List<Room>> myRooms() async {
    if (!enabled || _uid == null) return [];
    try {
      final rows = await _sb
          .from('rooms')
          .select('id, code, name, level_tag, owner, room_members(count)')
          .order('created_at', ascending: false);
      return (rows as List).whereType<Map>().map((j) {
        var count = 0;
        final rm = j['room_members'];
        if (rm is List && rm.isNotEmpty && rm.first is Map) {
          count = ((rm.first as Map)['count'] as num?)?.toInt() ?? 0;
        }
        return Room.fromJson(j, memberCount: count);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Creates a room (caller becomes owner). Returns it, or null on failure.
  Future<Room?> createRoom(String name, String level) async {
    if (!enabled || _uid == null) return null;
    try {
      final row = await _sb
          .rpc('create_room', params: {'p_name': name, 'p_level': level});
      final map = (row is List ? row.first : row) as Map;
      return Room.fromJson(map, memberCount: 1);
    } catch (_) {
      return null;
    }
  }

  /// Joins a room by invite code. Returns it, or null if not found / failure.
  Future<Room?> joinRoom(String code) async {
    if (!enabled || _uid == null) return null;
    try {
      final row = await _sb.rpc('join_room', params: {'p_code': code});
      final map = (row is List ? row.first : row) as Map;
      return Room.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Removes the caller's membership.
  Future<void> leaveRoom(String roomId) async {
    if (!enabled || _uid == null) return;
    try {
      await _sb
          .from('room_members')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', _uid!);
    } catch (_) {/* best-effort */}
  }

  /// Owner-only: deletes the room (cascades members + messages via FK).
  Future<void> deleteRoom(String roomId) async {
    if (!enabled || _uid == null) return;
    try {
      await _sb.from('rooms').delete().eq('id', roomId);
    } catch (_) {/* best-effort */}
  }

  /// Last [limit] messages in chronological order.
  Future<List<RoomMessage>> history(String roomId, {int limit = 50}) async {
    if (!enabled) return [];
    try {
      final rows = await _sb
          .from('room_messages')
          .select()
          .eq('room_id', roomId)
          .order('created_at', ascending: false)
          .limit(limit);
      final list = (rows as List)
          .whereType<Map>()
          .map(RoomMessage.fromJson)
          .toList();
      return list.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  /// Inserts a human message. Identity is snapshotted so old messages keep
  /// their author even if a profile later changes.
  Future<bool> sendMessage(
    String roomId, {
    required String body,
    required String authorName,
    required String authorHandle,
  }) async {
    if (!enabled || _uid == null) return false;
    try {
      await _sb.from('room_messages').insert({
        'room_id': roomId,
        'sender_id': _uid,
        'author_name': authorName,
        'author_handle': authorHandle,
        'is_guru': false,
        'body': body,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Asks the AI tutor to reply in the room (writes its own message server-side
  /// via the Edge Function). Returns null on success or an error code.
  Future<String?> callGuru(String roomId) async {
    if (!enabled || _uid == null) return 'offline';
    try {
      final res =
          await _sb.functions.invoke('group-guru', body: {'room_id': roomId});
      final data = res.data;
      if (data is Map && data['ok'] == true) return null;
      if (data is Map && data['error'] is String) return data['error'] as String;
      return 'failed';
    } catch (_) {
      return 'failed';
    }
  }

  /// Subscribes to a room: [onMessage] per new insert, [onPresence] with the
  /// current online count. The caller owns the returned channel and must
  /// `unsubscribe()` it when leaving. Returns null in guest mode.
  RealtimeChannel? subscribe(
    String roomId, {
    required void Function(RoomMessage) onMessage,
    required void Function(int online) onPresence,
    Map<String, dynamic>? presencePayload,
  }) {
    if (!enabled || _uid == null) return null;
    final ch = _sb.channel('room:$roomId');
    ch
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'room_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'room_id',
            value: roomId,
          ),
          callback: (payload) {
            try {
              onMessage(RoomMessage.fromJson(payload.newRecord));
            } catch (_) {/* ignore malformed */}
          },
        )
        .onPresenceSync((_) => onPresence(_countPresence(ch)))
        .onPresenceJoin((_) => onPresence(_countPresence(ch)))
        .onPresenceLeave((_) => onPresence(_countPresence(ch)))
        .subscribe((status, _) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await ch.track(presencePayload ?? {'user_id': _uid});
      }
    });
    return ch;
  }

  /// Distinct online users currently tracked on [ch].
  int _countPresence(RealtimeChannel ch) {
    try {
      final ids = <String>{};
      for (final state in ch.presenceState()) {
        for (final p in state.presences) {
          final uid = p.payload['user_id']?.toString();
          if (uid != null) ids.add(uid);
        }
      }
      return ids.isEmpty ? 1 : ids.length;
    } catch (_) {
      return 1;
    }
  }
}
