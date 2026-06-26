# Grup Realtime (M3) — Design

**Date:** 2026-06-13
**Status:** Approved (defaults finalized under `/goal` directive — build without further gating).
**Replaces:** the mock group screen (`app/lib/screens/grup.dart`, controller `roomMessages`/`sendRoom`) with real multi-user rooms backed by Supabase.

## Goal

Real study rooms: a user can **create** a room (becomes owner, gets an invite code), **join** another room by code, exchange **realtime** messages with other human members, see a live **online count** (presence), and call the **AI tutor (Guru)** into the room with an `@Guru` mention. Offline/guest mode degrades gracefully (the app and its 19 tests stay green with no backend).

## Decisions

- **Membership:** any signed-in user can create rooms and join by code. New users start with zero rooms (empty state).
- **Guru in group:** replies **only** when a message mentions `@Guru` (case-insensitive). Replies are concise — Mandarin plus a short Indonesian gloss (shorter than the private tutor).
- **Leaving:** a member can leave a room; the **owner** can disband (delete) a room (cascades members + messages).
- **No member cap** for now (YAGNI).
- **Realtime transport:** Supabase Realtime `postgres_changes` (INSERT on `room_messages`) for live messages + Realtime **Presence** for the online roster. No Broadcast.

## Data model (schema `public`)

```
rooms
  id          uuid pk default gen_random_uuid()
  code        text unique not null         -- 'ZWS-XXXXX' (5 base32 chars, no ambiguous I/O/0/1)
  name        text not null
  level_tag   text not null default ''     -- e.g. 'HSK 2', '繁體 TOCFL'
  owner       uuid not null -> auth.users
  created_at  timestamptz default now()

room_members
  room_id     uuid -> rooms (on delete cascade)
  user_id     uuid -> auth.users (on delete cascade)
  role        text default 'member'  check in ('owner','member')
  joined_at   timestamptz default now()
  primary key (room_id, user_id)

room_messages
  id           bigint generated always as identity pk
  room_id      uuid -> rooms (on delete cascade)
  sender_id    uuid null -> auth.users    -- null for Guru
  author_name  text not null              -- snapshot of display name (or 'Guru')
  author_handle text not null default ''  -- snapshot of handle ('' for Guru)
  is_guru      boolean not null default false
  body         text not null
  created_at   timestamptz default now()
```

`room_messages` added to the `supabase_realtime` publication so `postgres_changes` fires.

## RLS

- `rooms`: SELECT if `auth.uid()` is a member; UPDATE/DELETE only by `owner`.
- `room_members`: SELECT rows of rooms the caller belongs to; DELETE own row (leave).
- `room_messages`: SELECT if member of the room; INSERT if member **and** `sender_id = auth.uid()` and `is_guru = false`. Guru rows are written by the Edge Function with the service role (bypasses RLS).

To avoid the join chicken-and-egg (you must read a room to join, but can't read until you're a member), creation/join go through **security-definer RPCs**:

- `create_room(p_name text, p_level text) returns rooms` — generates a unique code, inserts the room with `owner = auth.uid()`, inserts the owner membership, returns the row.
- `join_room(p_code text) returns rooms` — finds the room by code, inserts membership for `auth.uid()` (idempotent), returns the row; raises if code invalid.

## Flutter

### `services/room_service.dart` (new)
Wraps Supabase. Pure data; no UI. Methods:
- `Future<List<Room>> myRooms()` — rooms the user belongs to (+ member counts).
- `Future<Room?> createRoom(name, level)` / `Future<Room?> joinRoom(code)` — call RPCs.
- `Future<void> leaveRoom(id)` / `Future<void> deleteRoom(id)`.
- `Future<List<RoomMessage>> history(roomId, {limit=50})`.
- `Future<void> sendMessage(roomId, body)` — insert with identity snapshot.
- `Future<void> callGuru(roomId)` — invoke `group-guru` Edge Function.
- `RealtimeChannel subscribe(roomId, {onMessage, onPresence})` — postgres_changes INSERT + presence track/sync; caller unsubscribes.

`enabled => zwsSupabaseReady` so everything no-ops in guest/test mode.

### Models
`Room {id, code, name, levelTag, owner, memberCount}`, `RoomMessage {id, senderId, authorName, authorHandle, isGuru, body, createdAt}`.

### Controller (`app_controller.dart`)
State: `List<Room> myRooms`, `Room? currentRoom`, `List<RoomMessage> roomMsgs`, `int roomOnline`, `roomInput`. Methods: `refreshMyRooms`, `createRoom`, `joinRoom`, `openRoomById` (loads history + subscribes), `closeRoomChannel`, `leaveCurrentRoom`, `deleteCurrentRoom`, `sendRoom` (insert; if body matches `@Guru` → also `callGuru`). Remove the old mock `roomMessages` seed and LLM-as-everyone behaviour.

### UI (`screens/grup.dart`)
- **Guest mode:** empty state "Masuk untuk pakai grup" (mirrors leaderboard).
- **No rooms:** "Buat ruang" (name field + level auto from track) and "Gabung via kode" (code field).
- **Has rooms:** list (name, member count, level) → tap opens the room.
- **Room view:** header (name, copyable code, "N online"), message list (me / other with avatar+handle / Guru styled), input with `@Guru` hint, overflow menu → Leave (or Disband if owner).
No emoji; existing `zws-design-system` components (`SurfaceBox`, `Pill`, `InkButton`, `Han`, `Mono`).

## Edge Function `group-guru`
`verify_jwt = true`. Body `{room_id}`. Steps: verify caller is a member (query with the caller's JWT); load last ~12 messages; build a concise group-tutor prompt (reply in Mandarin + short Indonesian gloss, address the asker); call the LLM (reuse `OPENCODE_ZEN_*`, same pattern as `translate`); insert a `room_messages` row with `is_guru=true`, `author_name='Guru'` using the **service role**. Realtime delivers it to everyone. On any failure, returns an error and inserts nothing (no fallback spam in a shared room).

## Error handling / graceful degradation
- All client calls are try/catch → non-crashing; failures surface as inline notices, never exceptions.
- Guest mode (`zwsSupabaseReady=false`): grup shows the sign-in empty state; no network.

## Testing
- **Unit:** invite-code format/validation, `RoomMessage.fromJson`, `@Guru` detection helper.
- **Widget:** grup renders the guest empty state with no backend (no throw); existing 19 tests stay green.
- **Live (not unit):** RLS + RPC + realtime delivery + `group-guru` verified against project `avdfneyqqmgzwzrmjtkv` via MCP `execute_sql` / REST — Realtime can't be exercised inside `flutter_test` (established project convention).

## Migration record
Applied via Supabase MCP `apply_migration`; the SQL is also saved to `supabase/migrations/` (folder created now) for repo history.
