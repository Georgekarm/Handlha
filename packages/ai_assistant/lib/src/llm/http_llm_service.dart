import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tool_models.dart';
import '../util/logger.dart';
import 'llm_service.dart';

/// Talks to YOUR backend (see backend/server.js), never to the LLM vendor
/// directly. The vendor API key lives only on the server.
///
/// Wire format (provider-neutral):
///   POST {AI_API_BASE_URL}/v1/chat
///   -> {conversation_id, system, messages[], tools[]}
///   <- {text?: string, tool_calls?: [{id, name, arguments}]}
///
/// `authTokenProvider` should return the signed-in user's short-lived ID token
/// (e.g. Firebase ID token). It is not a secret baked into the app.
class HttpLLMService implements LLMService {
  HttpLLMService({
    required String baseUrl,
    this.authTokenProvider,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.path = '/v1/chat',
    this.maxAttempts = 2,
    AssistantLogger? logger,
  })  : _base = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        _client = client ?? http.Client(),
        _logger = logger ?? const NoopLogger();

  /// Non-secret endpoint, injected at build time:
  ///   flutter run --dart-define=AI_API_BASE_URL=https://api.example.com
  static const envBaseUrl = String.fromEnvironment('AI_API_BASE_URL');

  final String _base;
  final String path;
  final Duration timeout;
  final int maxAttempts;
  final Future<String?> Function()? authTokenProvider;
  final http.Client _client;
  final AssistantLogger _logger;

  @override
  Future<LlmReply> complete(LlmRequest request) async {
    final uri = Uri.parse('$_base$path');
    final body = utf8.encode(jsonEncode(request.toJson()));
    LlmException? last;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final headers = <String, String>{
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        };
        final token = await authTokenProvider?.call();
        if (token != null && token.isNotEmpty) headers['Authorization'] = 'Bearer $token';

        final resp = await _client.post(uri, headers: headers, body: body).timeout(timeout);
        final code = resp.statusCode;
        if (code == 200) return _parse(utf8.decode(resp.bodyBytes));
        if (code == 401 || code == 403) throw LlmException(LlmErrorKind.unauthorized, 'HTTP $code');
        if (code == 429) throw LlmException(LlmErrorKind.rateLimited, 'HTTP 429');
        if (code >= 500) {
          last = LlmException(LlmErrorKind.network, 'HTTP $code');
        } else {
          throw LlmException(LlmErrorKind.invalidResponse, 'HTTP $code');
        }
      } on LlmException catch (e) {
        if (e.kind != LlmErrorKind.network && e.kind != LlmErrorKind.timeout) rethrow;
        last = e;
      } on TimeoutException {
        last = const LlmException(LlmErrorKind.timeout, 'timeout');
      } catch (e) {
        last = LlmException(LlmErrorKind.network, e.toString());
      }
      _logger.log(LogLevel.warning, 'LLM attempt $attempt failed: ${last.kind.name}');
      if (attempt < maxAttempts) {
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    throw last ?? const LlmException(LlmErrorKind.network, 'unknown');
  }

  LlmReply _parse(String raw) {
    Object? j;
    try {
      j = jsonDecode(raw);
    } catch (_) {
      throw const LlmException(LlmErrorKind.invalidResponse, 'non-JSON body');
    }
    if (j is! Map) throw const LlmException(LlmErrorKind.invalidResponse, 'not an object');
    final calls = <ToolCall>[];
    final rawCalls = j['tool_calls'];
    if (rawCalls is List) {
      for (final c in rawCalls) {
        if (c is Map) calls.add(ToolCall.fromJson(Map<String, dynamic>.from(c)));
      }
    }
    final text = j['text'] is String ? j['text'] as String : null;
    if ((text == null || text.trim().isEmpty) && calls.isEmpty) {
      throw const LlmException(LlmErrorKind.invalidResponse, 'empty reply');
    }
    return LlmReply(text: text, toolCalls: calls);
  }

  void close() => _client.close();
}
