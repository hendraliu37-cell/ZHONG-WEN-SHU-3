/// Backend configuration. The Supabase URL + anon key are *public* values
/// (the anon key is designed to ship in clients and is protected by RLS) — the
/// project rule "no secrets in the client" forbids the service-role / LLM /
/// Azure keys, never the anon key. Override at build time with
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`.
class ZwsConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://fcfpygtpkpmhpqcjywpb.supabase.co',
  );

  /// Modern publishable key (sb_publishable_...). Public by design, guarded by
  /// RLS. Overridable with `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`.
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_aa6D955-ZQ1gZ6py88Vjeg_7Wn0ucak',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}

/// Flipped to true by `main()` once `Supabase.initialize` succeeds. Stays false
/// in widget tests (which pump `ZwsApp` directly without calling `main()`), so
/// the app runs in offline "guest" mode there and the auth gate is skipped.
bool zwsSupabaseReady = false;
