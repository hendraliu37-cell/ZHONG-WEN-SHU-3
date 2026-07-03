import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Voice → text for the translator. Records a short clip to a temp WAV (16 kHz
/// mono) via `record`, then sends it to the `stt` Edge Function (cloud speech
/// recognition; key server-side). Degrades gracefully — never crashes.
class SttService {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;

  bool get enabled => zwsSupabaseReady;
  SupabaseClient get _sb => Supabase.instance.client;

  @visibleForTesting
  void setRecordingPathForTest(String path) {
    _path = path;
  }

  /// Begin recording. Returns false if there's no mic permission/device.
  Future<bool> start() async {
    try {
      if (!await _rec.hasPermission()) return false;
      final dir = await getTemporaryDirectory();
      _path =
          '${dir.path}/zws_stt_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _path!,
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('[stt] start failed: $e');
      return false;
    }
  }

  /// Stop recording and transcribe. [lang] is a BCP-47-ish hint ('zh' | 'id').
  Future<String?> stopAndTranscribe({String lang = 'zh'}) async {
    String? path;
    try {
      path = await _rec.stop() ?? _path;
      if (path == null) return null;
      final bytes = await File(path).readAsBytes();
      final b64 = base64Encode(bytes);
      if (!enabled) return null;
      final res = await _sb.functions.invoke(
        'stt',
        body: {'audio': b64, 'format': 'wav', 'lang': lang},
      );
      return _recognizedText(res.data);
    } catch (e) {
      if (kDebugMode) debugPrint('[stt] transcribe failed: $e');
      return null;
    } finally {
      _path = null;
      await _deleteTempRecording(path);
    }
  }

  Future<void> cancel() async {
    String? path;
    try {
      path = await _rec.stop() ?? _path;
    } catch (_) {}
    path ??= _path;
    _path = null;
    await _deleteTempRecording(path);
  }

  Future<void> _deleteTempRecording(String? path) async {
    if (path == null) return;
    try {
      await File(path).delete();
    } catch (_) {}
  }
}

String? _recognizedText(Object? data) {
  if (data is String) {
    final text = data.trim();
    if (text.isEmpty) return null;
    if (text.startsWith('{')) {
      try {
        return _recognizedText(jsonDecode(text));
      } catch (_) {
        // Fall through and treat it as plain recognized text.
      }
    }
    return text;
  }
  if (data is Map) {
    final text = data['text']?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
  return null;
}

@visibleForTesting
String? parseSttTextResponseForTest(Object? data) => _recognizedText(data);
