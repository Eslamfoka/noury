import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'ai_client.dart';
import 'ai_provider.dart';

/// **The only file in Nouri that opens a network connection.**
///
/// `no_network_test` holds that line: `HttpClient(` may appear here and
/// nowhere else under `lib/`, and the only hosts that may be named anywhere
/// are the three in `ai_provider.dart`. Everything the app sends leaves
/// through this file, so everything the app sends can be read in one place.
///
/// What it sends is decided by the caller — the prompt assembler keeps raw
/// rows out of the payload and a test proves it. What this file decides is
/// the *shape*: each provider's URL, header and JSON, and how its reply is
/// read back into plain text. Four providers, one method each way.
///
/// **Nothing here throws.** A socket that will not open, a 401, a body that
/// is not JSON, a reply with no text — every one comes back as an
/// [AiFailure] with a sentence the settings row can show. The user pressed a
/// button; the answer to a button is a sentence, not a stack trace.
class HttpAiClient implements AiClient {
  HttpAiClient({
    this.connectTimeout = const Duration(seconds: 20),
    this.listTimeout = const Duration(seconds: 30),
    this.completeTimeout = const Duration(seconds: 120),
  });

  final Duration connectTimeout;
  final Duration listTimeout;
  final Duration completeTimeout;

  static const _anthropicVersion = '2023-06-01';

  @override
  Future<AiResult<List<AiModel>>> listModels(AiConnection c) async {
    final refused = _check(c);
    if (refused != null) return AiResult.failed(refused);

    final (uri, headers) = switch (c.provider) {
      AiProvider.anthropic => (
          Uri.parse('${c.baseUrl}/v1/models?limit=100'),
          _anthropicHeaders(c),
        ),
      AiProvider.openai || AiProvider.compatible => (
          Uri.parse('${c.baseUrl}/models'),
          _bearerHeaders(c),
        ),
      AiProvider.gemini => (
          Uri.parse('${c.baseUrl}/v1beta/models?pageSize=100'),
          _geminiHeaders(c),
        ),
    };

    final reply = await _send('GET', uri, headers, null, listTimeout);
    if (!reply.ok) return AiResult.failed(reply.failure!);

    final body = reply.value!;
    final models = switch (c.provider) {
      AiProvider.anthropic ||
      AiProvider.openai ||
      AiProvider.compatible =>
        [
          for (final m in _listOf(body['data']))
            if (m is Map && m['id'] is String)
              AiModel(
                id: m['id'] as String,
                displayName: m['display_name'] as String?,
              ),
        ],
      AiProvider.gemini => [
          for (final m in _listOf(body['models']))
            if (m is Map &&
                m['name'] is String &&
                // Only the ones that can answer a chat. The list also holds
                // embedding and image models, which would fail on the call
                // that matters if picked.
                _listOf(m['supportedGenerationMethods'])
                    .contains('generateContent'))
              AiModel(
                id: (m['name'] as String).replaceFirst('models/', ''),
                displayName: m['displayName'] as String?,
              ),
        ],
    };

    // Newest-looking first is not something the services agree on, so keep
    // their order — it is the order their own consoles show.
    return AiResult.ok(models);
  }

  @override
  Future<AiResult<String>> complete(
    AiConnection c, {
    required String system,
    required String user,
    int maxTokens = 4096,
  }) async {
    final refused = _check(c);
    if (refused != null) return AiResult.failed(refused);

    final (uri, headers, body) = switch (c.provider) {
      AiProvider.anthropic => (
          Uri.parse('${c.baseUrl}/v1/messages'),
          _anthropicHeaders(c),
          {
            'model': c.model,
            'max_tokens': maxTokens,
            'system': system,
            'messages': [
              {'role': 'user', 'content': user},
            ],
          },
        ),
      AiProvider.openai || AiProvider.compatible => (
          Uri.parse('${c.baseUrl}/chat/completions'),
          _bearerHeaders(c),
          {
            'model': c.model,
            'messages': [
              {'role': 'system', 'content': system},
              {'role': 'user', 'content': user},
            ],
            // OpenAI retired `max_tokens` on its newer models in favour of
            // `max_completion_tokens`; most compatible servers know only the
            // old name. Each gets the one it understands.
            if (c.provider == AiProvider.openai)
              'max_completion_tokens': maxTokens
            else
              'max_tokens': maxTokens,
          },
        ),
      AiProvider.gemini => (
          Uri.parse('${c.baseUrl}/v1beta/models/${c.model}:generateContent'),
          _geminiHeaders(c),
          {
            'system_instruction': {
              'parts': [
                {'text': system},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': user},
                ],
              },
            ],
            'generationConfig': {'maxOutputTokens': maxTokens},
          },
        ),
    };

    final reply = await _send('POST', uri, headers, body, completeTimeout);
    if (!reply.ok) return AiResult.failed(reply.failure!);

    final text = switch (c.provider) {
      AiProvider.anthropic => _anthropicText(reply.value!),
      AiProvider.openai || AiProvider.compatible => _openAiText(reply.value!),
      AiProvider.gemini => _geminiText(reply.value!),
    };

    if (text == null || text.trim().isEmpty) {
      return const AiResult.failed(AiFailure(AiFailureKind.emptyReply));
    }
    return AiResult.ok(text);
  }

  // ------------------------------------------------------------ the request

  AiFailure? _check(AiConnection c) {
    if (!c.hasKey) return const AiFailure(AiFailureKind.noKey);
    if (!c.hasBaseUrl) return const AiFailure(AiFailureKind.noBaseUrl);
    return null;
  }

  Map<String, String> _anthropicHeaders(AiConnection c) => {
        'x-api-key': c.apiKey.trim(),
        'anthropic-version': _anthropicVersion,
      };

  Map<String, String> _bearerHeaders(AiConnection c) => {
        'authorization': 'Bearer ${c.apiKey.trim()}',
      };

  Map<String, String> _geminiHeaders(AiConnection c) => {
        'x-goog-api-key': c.apiKey.trim(),
      };

  /// One round trip, every failure folded into a sentence.
  Future<AiResult<Map<String, Object?>>> _send(
    String method,
    Uri uri,
    Map<String, String> headers,
    Map<String, Object?>? body,
    Duration timeout,
  ) async {
    final client = HttpClient()..connectionTimeout = connectTimeout;
    try {
      final request = await client.openUrl(method, uri).timeout(timeout);
      request.headers.contentType =
          ContentType('application', 'json', charset: 'utf-8');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      headers.forEach(request.headers.set);
      // Bytes, not `write`: the prompt is Arabic, and `HttpClientRequest.write`
      // encodes with whatever charset the content type declares — latin-1 by
      // default — which would turn every Arabic letter into a question mark
      // before it left the phone.
      if (body != null) request.add(utf8.encode(jsonEncode(body)));

      final response = await request.close().timeout(timeout);
      final text =
          await response.transform(utf8.decoder).join().timeout(timeout);

      Object? decoded;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        decoded = null;
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, Object?>) return AiResult.ok(decoded);
        return AiResult.failed(AiFailure(
          AiFailureKind.service,
          detail: 'reply was not JSON',
        ));
      }

      final detail = _errorMessage(decoded) ?? 'HTTP ${response.statusCode}';
      return AiResult.failed(switch (response.statusCode) {
        401 || 403 => AiFailure(AiFailureKind.badKey, detail: detail),
        // 402 is how some compatible services say the balance is gone.
        429 || 402 => AiFailure(AiFailureKind.rateLimited, detail: detail),
        _ => AiFailure(AiFailureKind.service, detail: detail),
      });
    } on TimeoutException {
      return const AiResult.failed(AiFailure(AiFailureKind.network, detail: 'timeout'));
    } on SocketException catch (e) {
      return AiResult.failed(AiFailure(AiFailureKind.network, detail: e.message));
    } on HttpException catch (e) {
      return AiResult.failed(AiFailure(AiFailureKind.network, detail: e.message));
    } on HandshakeException catch (e) {
      return AiResult.failed(AiFailure(AiFailureKind.network, detail: e.message));
    } catch (e) {
      // Anything else — a malformed URL the user typed, an OS error — is still
      // a sentence and not a crash.
      return AiResult.failed(AiFailure(AiFailureKind.network, detail: '$e'));
    } finally {
      client.close(force: true);
    }
  }

  /// The service's own words about what went wrong, if it gave any. All
  /// three named services put it at `error.message`; compatible ones mostly
  /// copy OpenAI. Trimmed hard: this ends up in a status row.
  static String? _errorMessage(Object? decoded) {
    if (decoded is! Map) return null;
    final error = decoded['error'];
    final message = switch (error) {
      Map() => error['message'],
      String() => error,
      _ => decoded['message'],
    };
    if (message is! String || message.trim().isEmpty) return null;
    final trimmed = message.trim();
    return trimmed.length > 160 ? '${trimmed.substring(0, 160)}…' : trimmed;
  }

  // -------------------------------------------------------------- the reply

  static String? _anthropicText(Map<String, Object?> body) {
    final parts = <String>[
      for (final block in _listOf(body['content']))
        if (block is Map && block['type'] == 'text' && block['text'] is String)
          block['text'] as String,
    ];
    return parts.isEmpty ? null : parts.join();
  }

  static String? _openAiText(Map<String, Object?> body) {
    final choices = _listOf(body['choices']);
    if (choices.isEmpty || choices.first is! Map) return null;
    final message = (choices.first as Map)['message'];
    if (message is! Map) return null;
    final content = message['content'];
    if (content is String) return content;
    // Some servers answer with a list of parts rather than one string.
    if (content is List) {
      return [
        for (final part in content)
          if (part is Map && part['text'] is String) part['text'] as String,
      ].join();
    }
    return null;
  }

  static String? _geminiText(Map<String, Object?> body) {
    final candidates = _listOf(body['candidates']);
    if (candidates.isEmpty || candidates.first is! Map) return null;
    final content = (candidates.first as Map)['content'];
    if (content is! Map) return null;
    final parts = <String>[
      for (final part in _listOf(content['parts']))
        if (part is Map && part['text'] is String) part['text'] as String,
    ];
    return parts.isEmpty ? null : parts.join();
  }

  static List<Object?> _listOf(Object? value) =>
      value is List ? value : const [];
}
