import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zhongwen_shu/services/auth_service.dart';

void main() {
  group('AuthService friendly errors', () {
    test('maps Supabase email send limit wording to actionable Indonesian', () {
      final auth = AuthService();

      final msg = auth.friendlyAuthErrorForTest(
        const AuthException(
          'For security purposes, you can only request this after 60 seconds',
        ),
      );

      expect(msg, contains('Batas kirim email tercapai'));
      expect(msg, contains('langsung coba masuk'));
    });

    test('maps underscore rate-limit codes too', () {
      final auth = AuthService();

      final msg = auth.friendlyAuthErrorForTest(
        const AuthException('over_email_send_rate_limit'),
      );

      expect(msg, contains('Batas kirim email tercapai'));
    });

    test('maps invalid credentials to a short local message', () {
      final auth = AuthService();

      final msg = auth.friendlyAuthErrorForTest(
        const AuthException('Invalid login credentials'),
      );

      expect(msg, 'Email atau kata sandi salah.');
    });

    test('maps handle unique constraint errors to username copy', () {
      final auth = AuthService();

      final msg = auth.friendlyAuthErrorForTest(
        'PostgrestException(code: 23505, message: duplicate key value '
        'violates unique constraint "profiles_handle_idx")',
      );

      expect(msg, 'Username sudah dipakai.');
    });
  });

  group('test history cloud rows', () {
    test('skips malformed payloads without dropping valid rows', () {
      final parsed = parseTestHistoryRowsForTest([
        {
          'payload': {
            'id': 'ok',
            'cardIds': [1],
          },
        },
        {'payload': null},
        'bad-row',
        {
          'payload': {
            'id': 'ok-2',
            'cardIds': ['2'],
          },
        },
        {
          'payload':
              '{"id":"ok-3","card_ids":["3",4],"updatedAt":"2026-07-03T00:00:00.000"}',
        },
        {
          'payload': {
            'cardIds': [99],
          },
        },
        {'payload': '{"cardIds":[100]}'},
        {'payload': '{"id":"   ","cardIds":[101]}'},
      ]);

      expect(parsed, hasLength(3));
      expect(parsed.first['id'], 'ok');
      expect(parsed.last['id'], 'ok-3');
      expect(parsed.last['card_ids'], ['3', 4]);
    });

    test('sync rows normalize timestamps and skip empty ids', () {
      final epochMs = DateTime.utc(2026, 7, 3, 10).millisecondsSinceEpoch;
      final epochSeconds =
          DateTime.utc(2026, 7, 3, 11).millisecondsSinceEpoch ~/ 1000;
      final dateTime = DateTime.utc(2026, 7, 3, 12, 30);

      final rows = testHistorySyncRowsForTest(
        [
          {'id': 'ms', 'updatedAt': epochMs},
          {'id': 'seconds', 'updatedAt': '$epochSeconds'},
          {'id': 'dt', 'updatedAt': dateTime},
          {'id': 'fallback', 'updatedAt': 'bad-date'},
          {'id': '  ', 'updatedAt': epochMs},
          {'updatedAt': epochMs},
        ],
        userId: 'user-1',
        fallbackUpdatedAt: '2026-07-03T00:00:00.000Z',
      );

      expect(rows.map((r) => r['id']), ['ms', 'seconds', 'dt', 'fallback']);
      expect(rows.every((r) => r['user_id'] == 'user-1'), isTrue);
      expect(rows[0]['updated_at'], '2026-07-03T10:00:00.000Z');
      expect(rows[1]['updated_at'], '2026-07-03T11:00:00.000Z');
      expect(rows[2]['updated_at'], dateTime.toIso8601String());
      expect(rows[3]['updated_at'], '2026-07-03T00:00:00.000Z');
      expect(rows[0]['payload'], containsPair('id', 'ms'));
    });
  });

  group('backend row parsers', () {
    test('profile parser normalizes loose field values', () {
      final profile = parseProfileRowForTest({
        'handle': 123,
        'public_id': '456.0',
        'display_name': null,
        'track': 'classic',
        'xp': '-9',
        'streak': '3.0',
        'avatar_url': '  ',
        'last_active_date': 20260702,
      });

      expect(profile.handle, '123');
      expect(profile.publicId, 456);
      expect(profile.displayName, '');
      expect(profile.track, 'both');
      expect(profile.xp, 0);
      expect(profile.streak, 3);
      expect(profile.avatarUrl, isNull);
      expect(profile.lastActiveDate, '20260702');
    });

    test('leaderboard parser skips bad rows and keeps typed UI fields', () {
      final rows = parseLeaderboardRowsForTest([
        'bad-row',
        {
          'handle': 123,
          'display_name': ' Budi ',
          'public_id': '77.0',
          'xp': '-12',
        },
        {'handle': null, 'display_name': null, 'public_id': null, 'xp': '800'},
      ]);

      expect(rows, hasLength(2));
      expect(rows.first, {
        'handle': '123',
        'display_name': 'Budi',
        'public_id': 77,
        'xp': 0,
      });
      expect(rows.last['handle'], '');
      expect(rows.last['xp'], 800);
    });
  });
}
