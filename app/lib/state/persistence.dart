import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin persistence wrapper. Stores the whole app state as one JSON blob under
/// a single key. Offline-first: no network, works on Windows + Android.
class Persistence {
  static const _key = 'zws_state_v1';
  SharedPreferences? _prefs;

  Future<void> _ensure() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<Map<String, dynamic>?> load() async {
    await _ensure();
    final raw = _prefs!.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> data) async {
    await _ensure();
    await _prefs!.setString(_key, jsonEncode(data));
  }

  Future<void> clear() async {
    await _ensure();
    await _prefs!.remove(_key);
  }
}
