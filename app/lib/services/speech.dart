import 'dart:async';
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
  @visibleForTesting
  static const neuralPlaybackRate = 0.72;
  @visibleForTesting
  static const osSpeechRate = 0.28;
  @visibleForTesting
  static const speechVolume = 1.0;
  @visibleForTesting
  static const osPitch = 1.04;

  final FlutterTts _tts = FlutterTts();
  AudioPlayer? _player;
  bool _enabled = true;
  bool _disposed = false;
  bool _configured = false;

  // text|lang → cached MP3 file path (cleared with the temp dir on restart).
  final Map<String, String> _cache = {};

  SupabaseClient get _sb => Supabase.instance.client;

  bool get _canSpeak => _enabled && !_disposed;

  @visibleForTesting
  bool get enabledForTest => _enabled;

  @visibleForTesting
  bool get disposedForTest => _disposed;

  /// Speak [text]; [traditional] picks zh-TW over zh-CN.
  Future<void> speak(String text, {bool traditional = false}) async {
    if (!_canSpeak || text.trim().isEmpty) return;
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
        final bytes = _audioBytes(res.data);
        if (bytes.isEmpty) return false;
        path = await _writeCache(key, bytes);
        _cache[key] = path;
      }
      if (!_canSpeak) return false;
      final p = _player ??= AudioPlayer();
      await p.stop();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume(speechVolume);
      await p.setPlaybackRate(neuralPlaybackRate);
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
      if (!_canSpeak) return;
      if (!_configured) {
        _configured = true;
        // Slow + clear so learners can hear each tone distinctly.
        await _tts.setSpeechRate(osSpeechRate);
        await _tts.setVolume(speechVolume);
        await _tts.setPitch(osPitch);
      }
      await _tts.stop();
      await _tts.setLanguage(traditional ? 'zh-TW' : 'zh-CN');
      await _tts.setSpeechRate(osSpeechRate);
      await _tts.setVolume(speechVolume);
      await _tts.setPitch(osPitch);
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('[TTS] OS engine unavailable: $e');
    }
  }

  Future<void> stop() async {
    await Future.wait([_stopPlayer(_player), _stopTts()]);
  }

  void setEnabled(bool v) {
    _enabled = v;
    if (!v) unawaited(stop());
  }

  void dispose() {
    _enabled = false;
    _disposed = true;
    final player = _player;
    _player = null;
    unawaited(_stopTts());
    if (player != null) unawaited(_disposePlayer(player));
  }

  Future<void> _stopPlayer(AudioPlayer? player) async {
    if (player == null) return;
    try {
      await player.stop();
    } catch (_) {
      // Best-effort cleanup. Some platforms throw after engine teardown.
    }
  }

  Future<void> _disposePlayer(AudioPlayer player) async {
    await _stopPlayer(player);
    try {
      await player.dispose();
    } catch (_) {
      // Best-effort cleanup. Some platforms throw after engine teardown.
    }
  }

  Future<void> _stopTts() async {
    try {
      await _tts.stop();
    } catch (_) {
      // Best-effort cleanup. Some platforms throw after engine teardown.
    }
  }
}

Uint8List _audioBytes(Object? data) {
  final raw = _audioPayload(data);
  if (raw == null || raw.isEmpty) return Uint8List(0);
  try {
    return base64Decode(raw);
  } catch (_) {
    return Uint8List(0);
  }
}

String? _audioPayload(Object? data) {
  if (data is String) {
    final text = data.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('{')) {
      try {
        return _audioPayload(jsonDecode(text));
      } catch (_) {
        // Fall through and treat it as a raw base64 payload.
      }
    }
    return text;
  }
  if (data is Map) {
    for (final key in const ['audio', 'audio_base64', 'base64']) {
      final text = data[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
  }
  return null;
}

@visibleForTesting
Uint8List parseTtsAudioResponseForTest(Object? data) => _audioBytes(data);
