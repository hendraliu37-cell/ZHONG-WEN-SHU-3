import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

class PronunciationWordScore {
  final String word;
  final int? confidence;

  const PronunciationWordScore({required this.word, this.confidence});

  factory PronunciationWordScore.fromJson(Map<dynamic, dynamic> json) =>
      PronunciationWordScore(
        word: (json['word'] ?? '').toString(),
        confidence: (json['confidence'] as num?)?.round(),
      );
}

class PronunciationResult {
  final String transcript;
  final int score;
  final List<PronunciationWordScore> words;

  const PronunciationResult({
    required this.transcript,
    required this.score,
    required this.words,
  });

  factory PronunciationResult.fromJson(Map<dynamic, dynamic> json) {
    final rows = json['words'];
    return PronunciationResult(
      transcript: (json['transcript'] ?? '').toString().trim(),
      score: ((json['score'] as num?) ?? 0).round().clamp(0, 100),
      words: rows is List
          ? rows
                .whereType<Map>()
                .map(PronunciationWordScore.fromJson)
                .where((w) => w.word.isNotEmpty)
                .toList()
          : const [],
    );
  }
}

class PronunciationService {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;
  String? lastError;

  bool get enabled => zwsSupabaseReady;
  SupabaseClient get _sb => Supabase.instance.client;

  Future<bool> start({InputDevice? device}) async {
    lastError = null;
    try {
      if (!await _rec.hasPermission()) {
        lastError = 'Izin mikrofon ditolak.';
        return false;
      }
      final dir = await getTemporaryDirectory();
      _path =
          '${dir.path}/zws_pron_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          device: device,
          autoGain: true,
        ),
        path: _path!,
      );
      return true;
    } catch (e) {
      lastError = 'Mikrofon gagal mulai: $e';
      if (kDebugMode) debugPrint('[pron] start failed: $e');
      return false;
    }
  }

  Future<PronunciationResult?> stopAndScore({
    required String referenceText,
    String lang = 'zh',
  }) async {
    String? path;
    try {
      path = await _rec.stop() ?? _path;
      if (path == null) {
        lastError = 'Tidak ada rekaman.';
        return null;
      }
      if (!enabled) {
        lastError = 'Supabase belum siap.';
        return null;
      }
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        lastError = 'Rekaman kosong.';
        return null;
      }
      final res = await _sb.functions.invoke(
        'scoring-proxy',
        body: {
          'audio': base64Encode(bytes),
          'format': 'wav',
          'reference_text': referenceText,
          'lang': lang,
        },
      );
      final data = res.data;
      if (data is Map && data['score'] != null) {
        lastError = null;
        return PronunciationResult.fromJson(data);
      }
      if (data is Map && data['error'] != null) {
        lastError = data['detail']?.toString() ?? data['error'].toString();
      } else {
        lastError = 'Skor tidak tersedia.';
      }
      return null;
    } catch (e) {
      lastError = 'Penilaian gagal: $e';
      if (kDebugMode) debugPrint('[pron] scoring failed: $e');
      return null;
    } finally {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> cancel() async {
    try {
      await _rec.stop();
    } catch (_) {}
  }
}
