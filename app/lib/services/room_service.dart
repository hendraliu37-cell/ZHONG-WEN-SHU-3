import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;
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
      return _parseRoomRows(rows);
    } catch (_) {
      return [];
    }
  }

  /// Creates a room (caller becomes owner). Returns it, or null on failure.
  Future<Room?> createRoom(String name, String level) async {
    if (!enabled || _uid == null) return null;
    try {
      final row = await _sb.rpc(
        'create_room',
        params: {'p_name': name, 'p_level': level},
      );
      return _parseRoomRpcRow(row, memberCount: 1);
    } catch (_) {
      return null;
    }
  }

  /// Joins a room by invite code. Returns it, or null if not found / failure.
  Future<Room?> joinRoom(String code) async {
    if (!enabled || _uid == null) return null;
    try {
      final row = await _sb.rpc('join_room', params: {'p_code': code});
      return _parseRoomRpcRow(row);
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
    } catch (_) {
      /* best-effort */
    }
  }

  /// Owner-only: deletes the room (cascades members + messages via FK).
  Future<void> deleteRoom(String roomId) async {
    if (!enabled || _uid == null) return;
    try {
      await _sb.from('rooms').delete().eq('id', roomId);
    } catch (_) {
      /* best-effort */
    }
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
      return _parseRoomHistoryRows(rows);
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
  Future<String?> callGuru(String roomId, {String track = 'simplified'}) async {
    if (!enabled || _uid == null) return 'offline';
    try {
      final res = await _sb.functions.invoke(
        'group-guru',
        body: {'room_id': roomId, 'track': track},
      );
      final data = res.data;
      return _parseGuruCallError(data);
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
            } catch (_) {
              /* ignore malformed */
            }
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

List<Room> _parseRoomRows(Object? rows) {
  if (rows is! List) return const [];
  return rows.whereType<Map>().map((j) {
    return Room.fromJson(j, memberCount: _parseMemberCount(j['room_members']));
  }).toList();
}

Room? _parseRoomRpcRow(Object? row, {int memberCount = 0}) {
  final payload = row is List ? (row.isEmpty ? null : row.first) : row;
  if (payload is! Map) return null;
  return Room.fromJson(payload, memberCount: memberCount);
}

List<RoomMessage> _parseRoomHistoryRows(Object? rows) {
  if (rows is! List) return const [];
  final list = rows.whereType<Map>().map(RoomMessage.fromJson).toList();
  return list.reversed.toList();
}

String? _parseGuruCallError(Object? data) {
  final map = _jsonObject(data);
  if (map != null) {
    if (_boolish(map['ok'])) return null;
    final error = map['error']?.toString().trim();
    if (error != null && error.isNotEmpty) return error;
  }
  return 'failed';
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

int _parseMemberCount(Object? value) {
  if (value is num) return value.toInt().clamp(0, 1 << 31);
  if (value is String) {
    final count = int.tryParse(value) ?? double.tryParse(value)?.toInt();
    return count == null ? 0 : count.clamp(0, 1 << 31);
  }
  if (value is List && value.isNotEmpty && value.first is Map) {
    return _parseMemberCount((value.first as Map)['count']);
  }
  if (value is Map) return _parseMemberCount(value['count']);
  return 0;
}

bool _boolish(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == 'true' || text == '1' || text == 'yes';
}

@visibleForTesting
List<Room> parseRoomRowsForTest(Object? rows) => _parseRoomRows(rows);

@visibleForTesting
Room? parseRoomRpcRowForTest(Object? row, {int memberCount = 0}) =>
    _parseRoomRpcRow(row, memberCount: memberCount);

@visibleForTesting
List<RoomMessage> parseRoomHistoryRowsForTest(Object? rows) =>
    _parseRoomHistoryRows(rows);

@visibleForTesting
String? parseGuruCallErrorForTest(Object? data) => _parseGuruCallError(data);
