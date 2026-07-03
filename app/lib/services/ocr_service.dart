import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// Photo → text for the translator. Lets the user pick an image (works on
/// desktop via `file_selector`), then sends it to the `ocr` Edge Function
/// (cloud vision model; key server-side) to extract the Chinese text.
class OcrService {
  bool get enabled => zwsSupabaseReady;
  SupabaseClient get _sb => Supabase.instance.client;

  /// Pick an image and return the recognized text, or null on cancel/failure.
  Future<String?> pickAndExtract() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'Gambar',
        extensions: ['jpg', 'jpeg', 'png', 'webp', 'bmp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return null; // user cancelled
      final bytes = await file.readAsBytes();
      final b64 = base64Encode(bytes);
      final name = file.name.toLowerCase();
      final mime = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
      if (!enabled) return null;
      final res = await _sb.functions.invoke(
        'ocr',
        body: {'image': b64, 'mime': mime},
      );
      return _recognizedText(res.data);
    } catch (e) {
      if (kDebugMode) debugPrint('[ocr] failed: $e');
      return null;
    }
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
        // Fall through and treat it as plain OCR text.
      }
    }
    return text;
  }
  if (data is Map) {
    for (final key in const [
      'text',
      'recognized_text',
      'recognizedText',
      'transcript',
      'result',
    ]) {
      final text = data[key]?.toString().trim() ?? '';
      if (text.isNotEmpty) return text;
    }
  }
  return null;
}

@visibleForTesting
String? parseOcrTextResponseForTest(Object? data) => _recognizedText(data);
