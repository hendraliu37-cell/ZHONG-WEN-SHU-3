import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

/// LLM client. Proxy-first (Supabase), direct fallback.
class LlmService {
  bool get enabled => true;

  SupabaseClient? get _sb {
    if (!zwsSupabaseReady) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? lastError;

  Future<String?> chat(
    List<Map<String, String>> messages, {
    required String track,
    String level = 'HSK 1-2',
  }) async {
    // 1. Try Supabase proxy
    final sb = _sb;
    if (sb != null) {
      try {
        final res = await sb.functions
            .invoke(
              'llm-proxy',
              body: {'messages': messages, 'track': track, 'level': level},
            )
            .timeout(const Duration(seconds: 30));
        final data = res.data;
        if (data is Map && data['reply'] is String) {
          final reply = (data['reply'] as String).trim();
          if (reply.isNotEmpty) {
            lastError = null;
            return reply;
          }
        }
        lastError = data is Map && data['error'] is String
            ? 'Proxy: ${data['error']}'
            : null; // fall through to direct
      } catch (e) {
        lastError = null; // fall through
      }
    }

    // 2. Direct fallback for dev builds. Production should use llm-proxy so
    // keys never ship in the APK.
    final key = const String.fromEnvironment(
      'OPENMODEL_API_KEY',
      defaultValue: String.fromEnvironment(
        'OPENCODE_GO_API_KEY',
        defaultValue: String.fromEnvironment('OPENCODE_ZEN_API_KEY'),
      ),
    );
    if (key.isEmpty) {
      return null;
    }

    final variant = track == 'traditional'
        ? 'TRADITIONAL_ONLY: pakai hanzi tradisional. Jangan tulis simplified kecuali user minta bandingkan.'
        : 'SIMPLIFIED_ONLY: pakai hanzi sederhana. Jangan tulis traditional kecuali user minta bandingkan.';
    final system =
        'Kamu Guru Mandarin untuk penutur Indonesia. Baca pesan user dan jawab sesuai konteks. '
        'Ikuti track hanzi secara ketat: $variant '
        'Format rapi, maksimal 4 blok pendek dengan label: Ringkas:, Contoh:, Catatan:, Latihan:. '
        'Format kata baru: hanzi (pinyin) = arti Indonesia. Jangan pakai tabel, code fence, placeholder, atau emoji.';
    final body = [
      {'role': 'system', 'content': system},
      ...messages,
    ];

    final baseUrl = const String.fromEnvironment(
      'OPENMODEL_BASE_URL',
      defaultValue: String.fromEnvironment(
        'OPENCODE_GO_BASE_URL',
        defaultValue: 'https://api.openmodel.ai',
      ),
    );
    final openModel =
        const bool.hasEnvironment('OPENMODEL_API_KEY') ||
        baseUrl.contains('openmodel.ai');
    final root = baseUrl
        .replaceFirst(RegExp(r'/+$'), '')
        .replaceFirst(RegExp(r'/v1$'), '');
    final endpoint = openModel
        ? '$root/v1/messages'
        : (baseUrl.endsWith('/chat/completions')
              ? baseUrl
              : '$root/v1/chat/completions');

    for (final model in const [
      'deepseek-v4-flash',
      'deepseek-v4-flash-free',
      'deepseek-chat',
    ]) {
      try {
        final resp = await http
            .post(
              Uri.parse(endpoint),
              headers: openModel
                  ? {
                      'x-api-key': key,
                      'anthropic-version': '2023-06-01',
                      'Content-Type': 'application/json',
                    }
                  : {
                      'Authorization': 'Bearer $key',
                      'Content-Type': 'application/json',
                    },
              body: openModel
                  ? jsonEncode({
                      'model': model,
                      'system': system,
                      'messages': messages,
                      'temperature': 0.8,
                      'max_tokens': 800,
                    })
                  : jsonEncode({
                      'model': model,
                      'messages': body,
                      'temperature': 0.8,
                      'max_tokens': 800,
                    }),
            )
            .timeout(const Duration(seconds: 30));
        if (resp.statusCode == 200) {
          try {
            final data = jsonDecode(resp.body);
            final reply = openModel
                ? _openModelText(data)
                : data['choices']?[0]?['message']?['content'] as String?;
            if (reply != null && reply.trim().isNotEmpty) {
              lastError = null;
              return reply.trim();
            }
          } catch (_) {
            lastError = 'Bad JSON: ${resp.body.substring(0, 100)}';
          }
        } else if (resp.statusCode == 401 || resp.statusCode == 403) {
          lastError =
              'Auth(${resp.statusCode}) for $model: ${resp.body.substring(0, 100)}';
          break;
        } else {
          lastError =
              'HTTP ${resp.statusCode} for $model: ${resp.body.substring(0, 80)}';
        }
      } catch (e) {
        lastError = 'Net: $e'.substring(0, 100);
        break;
      }
    }

    return null;
  }

  String? _openModelText(dynamic data) {
    final content = data is Map ? data['content'] : null;
    if (content is String) return content;
    if (content is List) {
      final out = StringBuffer();
      for (final part in content) {
        if (part is String) {
          out.write(part);
        } else if (part is Map && part['text'] is String) {
          out.write(part['text'] as String);
        }
      }
      final text = out.toString().trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }
}
