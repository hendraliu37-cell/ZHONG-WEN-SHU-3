import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Card / text audio (TTS).
///
/// Primary path: the `tts` Edge Function (clear, tonally-correct neural Mandarin
/// — far better than the OS engine), returned as MP3, cached on disk and played
/// with `audioplayers`. Fallback: the OS engine via `flutter_tts` (used offline,
/// in tests, or if the network path fails). Every call is guarded — it stays a
/// silent no-op rather than crashing when no engine/voice is available.
class SpeechService {
  final FlutterTts _tts = FlutterTts();
  AudioPlayer? _player;
  bool _enabled = true;
  bool _configured = false;

  // text|lang → cached MP3 file path (cleared with the temp dir on restart).
  final Map<String, String> _cache = {};

  SupabaseClient get _sb => Supabase.instance.client;

  /// Speak [text]; [traditional] picks zh-TW over zh-CN.
  Future<void> speak(String text, {bool traditional = false}) async {
    if (!_enabled || text.trim().isEmpty) return;
    if (zwsSupabaseReady && await _speakNeural(text, traditional)) return;
    await _speakOs(text, traditional);
  }

  /// Neural path via the Edge Function (cached). Returns true if it played.
  Future<bool> _speakNeural(String text, bool traditional) async {
    final lang = traditional ? 'zh-TW' : 'zh-CN';
    final key = 'slow-v2|$lang|$text';
    try {
      var path = _cache[key];
      if (path == null || !File(path).existsSync()) {
        final res = await _sb.functions.invoke(
          'tts',
          body: {
            'text': text,
            'track': traditional ? 'traditional' : 'simplified',
          },
        );
        final data = res.data;
        if (data is! Map || data['audio'] is! String) return false;
        final bytes = base64Decode(data['audio'] as String);
        if (bytes.isEmpty) return false;
        path = await _writeCache(key, bytes);
        _cache[key] = path;
      }
      final p = _player ??= AudioPlayer();
      await p.stop();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(1.0);
      await p.setPlaybackRate(0.78);
      await p.play(DeviceFileSource(path));
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] neural failed: $e');
      return false;
    }
  }

  Future<String> _writeCache(String key, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final name = 'zws_tts_${_hash(key)}.mp3';
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// FNV-1a hash → stable hex filename for the cache.
  static String _hash(String s) {
    var h = 0x811c9dc5;
    for (final c in s.codeUnits) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h.toRadixString(16);
  }

  /// OS engine fallback (flutter_tts).
  Future<void> _speakOs(String text, bool traditional) async {
    try {
      if (!_configured) {
        _configured = true;
        // Slow + clear so learners can hear each tone distinctly.
        await _tts.setSpeechRate(0.28);
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.04);
      }
      await _tts.stop();
      await _tts.setLanguage(traditional ? 'zh-TW' : 'zh-CN');
      await _tts.setSpeechRate(0.28);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.04);
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] OS engine unavailable: $e');
    }
  }

  void setEnabled(bool v) => _enabled = v;

  void dispose() {
    _player?.dispose();
  }
}
