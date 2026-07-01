import 'package:flutter_test/flutter_test.dart';
import 'package:zhongwen_shu/models/room.dart';

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
  });
}
