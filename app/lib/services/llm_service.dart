import 'dart:convert';
import 'package:flutter/foundation.dart' show visibleForTesting;
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
    String? systemOverride,
    double temperature = 0.8,
    int maxTokens = 800,
  }) async {
    final variant = track == 'traditional'
        ? 'TRADITIONAL_ONLY: pakai hanzi tradisional. Jangan tulis simplified kecuali user minta bandingkan.'
        : 'SIMPLIFIED_ONLY: pakai hanzi sederhana. Jangan tulis traditional kecuali user minta bandingkan.';
    final system =
        systemOverride ??
        'Kamu Guru Mandarin untuk penutur Indonesia. Baca pesan user dan jawab sesuai konteks. '
            'Ikuti track hanzi secara ketat: $variant '
            'Format rapi, maksimal 4 blok pendek dengan label: Ringkas:, Contoh:, Catatan:, Latihan:. '
            'Format kata baru: hanzi (pinyin) = arti Indonesia. Jangan pakai tabel, code fence, placeholder, atau emoji.';

    // 1. Try Supabase proxy
    final sb = _sb;
    if (sb != null) {
      try {
        final proxyBody = <String, Object?>{
          'messages': messages,
          'track': track,
          'level': level,
          'temperature': temperature,
          'max_tokens': maxTokens,
        };
        if (systemOverride != null) proxyBody['system'] = systemOverride;
        final res = await sb.functions
            .invoke('llm-proxy', body: proxyBody)
            .timeout(const Duration(seconds: 30));
        final data = _jsonObject(res.data);
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
                      'temperature': temperature,
                      'max_tokens': maxTokens,
                    })
                  : jsonEncode({
                      'model': model,
                      'messages': body,
                      'temperature': temperature,
                      'max_tokens': maxTokens,
                    }),
            )
            .timeout(const Duration(seconds: 30));
        if (resp.statusCode == 200) {
          try {
            final data = jsonDecode(resp.body);
            final reply = openModel
                ? _openModelText(data)
                : _openAiChatText(data);
            if (reply != null && reply.trim().isNotEmpty) {
              lastError = null;
              return reply.trim();
            }
          } catch (_) {
            lastError = 'Bad JSON: ${_snippet(resp.body, 100)}';
          }
        } else if (resp.statusCode == 401 || resp.statusCode == 403) {
          lastError =
              'Auth(${resp.statusCode}) for $model: ${_snippet(resp.body, 100)}';
          if (!_isModelSelectionError(resp.body)) break;
        } else {
          lastError =
              'HTTP ${resp.statusCode} for $model: ${_snippet(resp.body, 80)}';
        }
      } catch (e) {
        lastError = 'Net: $e'.substring(0, 100);
        break;
      }
    }

    return null;
  }

  String _snippet(String text, int max) =>
      text.length <= max ? text : text.substring(0, max);

  bool _isModelSelectionError(String body) =>
      _looksLikeModelSelectionError(body);

  String? _openModelText(dynamic data) {
    final content = data is Map ? data['content'] : null;
    return _contentText(content);
  }

  String? _openAiChatText(dynamic data) {
    final choices = data is Map ? data['choices'] : null;
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    final message = first is Map ? first['message'] : null;
    if (message is! Map) return null;
    return _contentText(message['content']);
  }
}

String? _contentText(Object? content) {
  if (content is String) return content;
  if (content is List) {
    final out = StringBuffer();
    for (final part in content) {
      if (part is String) {
        out.write(part);
      } else if (part is Map) {
        final text = part['text'] ?? part['content'];
        if (text is String) out.write(text);
      }
    }
    final text = out.toString().trim();
    return text.isEmpty ? null : text;
  }
  return null;
}

Map<dynamic, dynamic>? _jsonObject(Object? data) {
  if (data is Map) return data;
  if (data is String) {
    final text = data.trim();
    if (!text.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map ? decoded : null;
    } catch (_) {
      return null;
    }
  }
  return null;
}

@visibleForTesting
String? parseLlmProxyReplyForTest(Object? data) {
  final map = _jsonObject(data);
  final reply = map?['reply'];
  return reply is String && reply.trim().isNotEmpty ? reply.trim() : null;
}

@visibleForTesting
String? parseOpenModelTextForTest(Object? data) =>
    LlmService()._openModelText(data);

@visibleForTesting
String? parseOpenAiChatTextForTest(Object? data) =>
    LlmService()._openAiChatText(data);

@visibleForTesting
bool looksLikeModelSelectionErrorForTest(String body) =>
    _looksLikeModelSelectionError(body);

bool _looksLikeModelSelectionError(String body) {
  final text = body.toLowerCase();
  return text.contains('modelerror') ||
      text.contains('model_not_found') ||
      text.contains('model not found') ||
      text.contains('invalid model') ||
      text.contains('unknown model');
}
