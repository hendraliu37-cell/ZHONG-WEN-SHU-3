import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models/curriculum.dart';

/// Fetches/generates daily learning materials via the curriculum-gen Edge Function.
class CurriculumService {
  bool get enabled => zwsSupabaseReady;

  SupabaseClient get _sb => Supabase.instance.client;

  /// Fetches materials for the given [track] and [level]. Returns cached content
  /// when available, generates fresh only when [force] is true.
  Future<DailyMaterial?> fetch({
    required String track,
    String level = 'HSK 1-2',
    bool force = false,
  }) async {
    if (!enabled) return null;
    try {
      final res = await _sb.functions.invoke(
        'curriculum-gen',
        body: {'track': track, 'level': level, if (force) 'force': true},
      );
      final data = res.data;
      if (data == null) return null;

      // Edge function returns { cached, materials: [...] }
      return parseCurriculumResponse(data);
    } catch (_) {
      return null;
    }
  }
}

DailyMaterial? parseCurriculumResponse(Object? data) {
  final decoded = _jsonValue(data);
  final materials = decoded is Map
      ? (decoded['materials'] ?? decoded['material'] ?? decoded['data'])
      : decoded;
  final list = materials is List
      ? materials
      : (materials == null ? null : [materials]);
  if (list == null) return null;
  for (final item in list) {
    if (item is! Map) continue;
    final material = DailyMaterial.fromJson(Map<String, dynamic>.from(item));
    if (material.topic.isNotEmpty ||
        material.vocab.isNotEmpty ||
        material.sentences.isNotEmpty ||
        material.exercise.isNotEmpty) {
      return material;
    }
  }
  return null;
}

Object? _jsonValue(Object? data) {
  if (data is String) {
    final text = data.trim();
    if (!text.startsWith('{') && !text.startsWith('[')) return data;
    try {
      return jsonDecode(text);
    } catch (_) {
      return data;
    }
  }
  return data;
}
