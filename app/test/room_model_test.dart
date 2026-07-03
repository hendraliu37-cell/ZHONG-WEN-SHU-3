import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/models/room.dart';
import 'package:zhongwen_shu/services/room_service.dart';

void main() {
  group('mentionsGuru', () {
    test('detects a plain @Guru call, case-insensitive', () {
      expect(mentionsGuru('@Guru apa arti 喜欢?'), isTrue);
      expect(mentionsGuru('halo @guru tolong jelaskan'), isTrue);
      expect(mentionsGuru('eh @GURU'), isTrue);
      expect(mentionsGuru('halo ＠guru tolong jelaskan'), isTrue);
    });
    test('ignores non-mentions and look-alikes', () {
      expect(mentionsGuru('guru kami baik'), isFalse);
      expect(mentionsGuru('email @guru.com bukan mention'), isFalse);
      expect(mentionsGuru('@gurun salah'), isFalse);
      expect(mentionsGuru('＠gurun salah'), isFalse);
      expect(mentionsGuru(''), isFalse);
    });

    test('detects Guru mention prefixes for suggestions', () {
      expect(isGuruMentionPrefix('@'), isTrue);
      expect(isGuruMentionPrefix('@g'), isTrue);
      expect(isGuruMentionPrefix('@Gu'), isTrue);
      expect(isGuruMentionPrefix('＠gur'), isTrue);
      expect(isGuruMentionPrefix('guru'), isFalse);
      expect(isGuruMentionPrefix('@gurun'), isFalse);
    });

    test('inserts the Guru mention at the active token', () {
      final plain = insertGuruMention('@', 1);
      expect(plain.text, '@Guru ');
      expect(plain.caret, 6);

      final sentence = insertGuruMention('tolong @g jelaskan', 9);
      expect(sentence.text, 'tolong @Guru jelaskan');
      expect(sentence.caret, 13);

      final noCaret = insertGuruMention('halo @', -1);
      expect(noCaret.text, 'halo @Guru ');
      expect(noCaret.caret, 11);
    });
  });

  group('room code', () {
    test('normalizes loose input to ZWS-XXXXX', () {
      expect(normalizeRoomCode('7f3kq'), 'ZWS-7F3KQ');
      expect(normalizeRoomCode('zws-7f3kq'), 'ZWS-7F3KQ');
      expect(normalizeRoomCode('  ZWS - 7F3KQ '), 'ZWS-7F3KQ');
      expect(normalizeRoomCode(''), '');
    });
    test('validates canonical codes only', () {
      expect(isValidRoomCode('ZWS-7F3KQ'), isTrue);
      expect(isValidRoomCode('ZWS-ABCDE'), isTrue);
      expect(isValidRoomCode('ZWS-7F3K'), isFalse); // too short
      expect(isValidRoomCode('ZWS-0O1IL'), isFalse); // ambiguous chars excluded
      expect(isValidRoomCode('7F3KQ'), isFalse); // missing prefix
    });
  });

  group('RoomMessage.fromJson', () {
    test('parses a server row including Guru flag', () {
      final m = RoomMessage.fromJson({
        'id': 42,
        'sender_id': 'u-1',
        'author_name': 'Budi',
        'author_handle': 'budi',
        'is_guru': false,
        'body': '你好',
        'created_at': '2026-06-13T03:00:00Z',
      });
      expect(m.id, 42);
      expect(m.authorName, 'Budi');
      expect(m.isGuru, isFalse);
      expect(m.isMine('u-1'), isTrue);
      expect(m.isMine('u-2'), isFalse);

      final g = RoomMessage.fromJson({
        'id': 43,
        'sender_id': null,
        'author_name': 'Guru',
        'is_guru': true,
        'body': '很好',
        'created_at': '2026-06-13T03:01:00Z',
      });
      expect(g.isGuru, isTrue);
      expect(g.senderId, isNull);
      expect(g.isMine('u-1'), isFalse);
    });

    test('normalizes loose realtime row field types', () {
      final m = RoomMessage.fromJson({
        'id': '44.0',
        'sender_id': '  ',
        'author_name': 123,
        'author_handle': null,
        'is_guru': 'true',
        'body': 456,
        'created_at': 'bad-date',
      });

      expect(m.id, 44);
      expect(m.senderId, isNull);
      expect(m.authorName, '123');
      expect(m.authorHandle, '');
      expect(m.isGuru, isTrue);
      expect(m.body, '456');
      expect(m.createdAt, isA<DateTime>());
    });

    test('accepts numeric created_at timestamps', () {
      final epochMs = DateTime.utc(2026, 7, 2, 10).millisecondsSinceEpoch;
      final epochSeconds =
          DateTime.utc(2026, 7, 2, 11).millisecondsSinceEpoch ~/ 1000;

      final fromMs = RoomMessage.fromJson({
        'id': 45,
        'body': 'epoch ms',
        'created_at': epochMs,
      });
      final fromSeconds = RoomMessage.fromJson({
        'id': 46,
        'body': 'epoch seconds',
        'created_at': '$epochSeconds',
      });

      expect(
        fromMs.createdAt,
        DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true).toLocal(),
      );
      expect(
        fromSeconds.createdAt,
        DateTime.fromMillisecondsSinceEpoch(
          epochSeconds * 1000,
          isUtc: true,
        ).toLocal(),
      );
    });
  });

  group('RoomService backend parsers', () {
    test('room rows tolerate loose member-count shapes', () {
      final rooms = parseRoomRowsForTest([
        {
          'id': 'r1',
          'code': 'ZWS-ABCDE',
          'name': 'Kelas A',
          'level_tag': 'HSK 1',
          'owner': 'u1',
          'room_members': [
            {'count': '3.0'},
          ],
        },
        {
          'id': 'r2',
          'code': 'ZWS-FGHIJ',
          'name': 'Kelas B',
          'room_members': {'count': 2},
        },
        {
          'id': '',
          'code': 'ZWS-BAD01',
          'name': 'Kosong',
          'room_members': {'count': 9},
        },
        {
          'id': 'r3',
          'code': '',
          'name': 'Tanpa kode',
          'room_members': {'count': 1},
        },
        'bad-row',
      ]);

      expect(rooms, hasLength(2));
      expect(rooms.first.memberCount, 3);
      expect(rooms.last.memberCount, 2);
    });

    test('RPC row parser rejects empty or malformed payloads', () {
      expect(parseRoomRpcRowForTest([]), isNull);
      expect(parseRoomRpcRowForTest('bad'), isNull);
      expect(parseRoomRpcRowForTest({'id': '', 'code': 'ZWS-ABCDE'}), isNull);
      expect(parseRoomRpcRowForTest({'id': 'r1', 'code': ''}), isNull);

      final room = parseRoomRpcRowForTest([
        {'id': 'r1', 'code': 'ZWS-ABCDE', 'name': 'Kelas'},
      ], memberCount: 1);

      expect(room, isNotNull);
      expect(room!.memberCount, 1);
      expect(room.name, 'Kelas');
    });

    test('history parser skips bad rows and restores chronological order', () {
      final epochMs = DateTime.utc(2026, 7, 2, 01).millisecondsSinceEpoch;
      final epochSeconds =
          DateTime.utc(2026, 7, 2, 03).millisecondsSinceEpoch ~/ 1000;
      final history = parseRoomHistoryRowsForTest([
        {
          'id': 2,
          'author_name': 'Guru',
          'is_guru': true,
          'body': 'baik',
          'created_at': '2026-07-02T02:00:00Z',
        },
        {
          'id': 4,
          'author_name': 'Ani',
          'body': 'paling akhir',
          'created_at': '$epochSeconds',
        },
        'bad-row',
        {'id': 3, 'body': '  ', 'created_at': '2026-07-02T03:00:00Z'},
        {'id': 0, 'body': 'optimistic stale'},
        {
          'id': 1,
          'author_name': 'Hendra',
          'body': 'halo',
          'created_at': epochMs,
        },
      ]);

      expect(history.map((m) => m.id), [1, 2, 4]);
      expect(history[1].isGuru, isTrue);
    });

    test('Guru call parser accepts loose ok and error payloads', () {
      expect(parseGuruCallErrorForTest({'ok': 'true'}), isNull);
      expect(parseGuruCallErrorForTest({'ok': 1}), isNull);
      expect(parseGuruCallErrorForTest('{"ok":true}'), isNull);
      expect(parseGuruCallErrorForTest('{"error":"llm_failed"}'), 'llm_failed');
      expect(parseGuruCallErrorForTest({'error': 123}), '123');
      expect(parseGuruCallErrorForTest({'error': '  '}), 'failed');
      expect(parseGuruCallErrorForTest('bad'), 'failed');
    });
  });

  group('room failure copy', () {
    test('explains send and Guru failures in Indonesian', () {
      expect(roomSendFailureMessage(), contains('Pesan belum terkirim'));
      expect(roomGuruFailureMessage('offline'), contains('offline'));
      expect(roomGuruFailureMessage('not_member'), contains('ruang'));
      expect(roomGuruFailureMessage('llm_failed'), contains('Coba ulang'));
      expect(
        roomGuruFailureMessage('unknown'),
        contains('Guru belum tersedia'),
      );
    });
  });
}
