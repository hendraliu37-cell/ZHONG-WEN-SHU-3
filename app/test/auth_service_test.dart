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
      ]);

      expect(parsed, hasLength(2));
      expect(parsed.first['id'], 'ok');
      expect(parsed.last['id'], 'ok-2');
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
