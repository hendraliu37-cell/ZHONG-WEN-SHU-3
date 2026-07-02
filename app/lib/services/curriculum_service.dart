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
  final materials = data is Map ? data['materials'] : null;
  if (materials is! List) return null;
  for (final item in materials) {
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
