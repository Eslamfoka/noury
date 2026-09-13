import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/features/ai/ai_client.dart';
import 'package:nouri/features/ai/ai_http_client.dart';
import 'package:nouri/features/ai/ai_provider.dart';

/// The one file that opens a socket, tested against a socket.
///
/// A loopback `HttpServer` stands in for each service and records what
/// arrived — path, headers, body — then answers with the shape that service
/// documents. Nothing here reaches the internet: `baseUrl` on the connection
/// points every provider at 127.0.0.1, which is also how the compatible
/// provider works for real.
///
/// Two claims per provider: the request is the one its API expects, and its
/// reply is read back into plain text. And for all of them: every way a call
/// can fail comes back as a sentence, never as a throw.
void main() {
  late HttpServer server;
  late List<_Seen> seen;
  late Future<void> Function(HttpRequest) answer;

  setUp(() async {
    seen = [];
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final body = await utf8.decoder.bind(req).join();
      seen.add(_Seen(
        method: req.method,
        path: req.uri.toString(),
        headers: {
          for (final name in ['x-api-key', 'anthropic-version', 'authorization', 'x-goog-api-key'])
            if (req.headers.value(name) != null) name: req.headers.value(name)!,
        },
        body: body.isEmpty ? null : jsonDecode(body) as Map<String, Object?>,
      ));
      await answer(req);
    });
  });

  tearDown(() => server.close(force: true));

  String base() => 'http://127.0.0.1:${server.port}';

  Future<void> Function(HttpRequest) json(int status, Object body) =>
      (req) async {
        req.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(body));
        await req.response.close();
      };

  AiConnection conn(AiProvider p, {String key = 'sk-test', String? model}) =>
      AiConnection(provider: p, apiKey: key, model: model, baseUrl: base());

  final client = HttpAiClient(
    connectTimeout: const Duration(seconds: 2),
    listTimeout: const Duration(seconds: 2),
    completeTimeout: const Duration(seconds: 2),
  );

  group('Claude', () {
    test('lists models with the key in x-api-key and a version header', () async {
      answer = json(200, {
        'data': [
          {'id': 'claude-haiku-4-5', 'display_name': 'Claude Haiku 4.5'},
          {'id': 'claude-opus-5', 'display_name': 'Claude Opus 5'},
        ],
      });

      final result = await client.listModels(conn(AiProvider.anthropic));

      expect(result.ok, isTrue, reason: '${result.failure}');
      expect(result.value!.map((m) => m.id), ['claude-haiku-4-5', 'claude-opus-5']);
      expect(result.value!.first.displayName, 'Claude Haiku 4.5');

      final req = seen.single;
      expect(req.method, 'GET');
      expect(req.path, startsWith('/v1/models'));
      expect(req.headers['x-api-key'], 'sk-test');
      expect(req.headers['anthropic-version'], '2023-06-01');
      expect(req.headers.containsKey('authorization'), isFalse);
    });

    test('posts a message with system and user, and reads the text blocks', () async {
      answer = json(200, {
        'content': [
          {'type': 'text', 'text': '{"days":[]'},
          {'type': 'text', 'text': ',"note":"تمام"}'},
        ],
        'stop_reason': 'end_turn',
      });

      final result = await client.complete(
        conn(AiProvider.anthropic, model: 'claude-haiku-4-5'),
        system: 'أنت نوري',
        user: 'ابني الخطة',
        maxTokens: 777,
      );

      expect(result.ok, isTrue, reason: '${result.failure}');
      expect(result.value, '{"days":[],"note":"تمام"}');

      final req = seen.single;
      expect(req.method, 'POST');
      expect(req.path, '/v1/messages');
      expect(req.body!['model'], 'claude-haiku-4-5');
      expect(req.body!['max_tokens'], 777);
      expect(req.body!['system'], 'أنت نوري');
      expect(req.body!['messages'], [
        {'role': 'user', 'content': 'ابني الخطة'},
      ]);
    });

    test('uses Haiku when no model was chosen', () async {
      answer = json(200, {'content': []});
      await client.complete(conn(AiProvider.anthropic), system: 's', user: 'u');
      expect(seen.single.body!['model'], 'claude-haiku-4-5');
    });
  });

  group('OpenAI and compatible', () {
    test('lists models with a bearer token', () async {
      answer = json(200, {
        'data': [
          {'id': 'gpt-4o-mini', 'object': 'model'},
        ],
      });

      final result = await client.listModels(conn(AiProvider.openai));

      expect(result.value!.single.id, 'gpt-4o-mini');
      expect(seen.single.path, '/models');
      expect(seen.single.headers['authorization'], 'Bearer sk-test');
      expect(seen.single.headers.containsKey('x-api-key'), isFalse);
    });

    test('posts a chat completion and reads the first choice', () async {
      answer = json(200, {
        'choices': [
          {
            'message': {'role': 'assistant', 'content': 'أهلاً'},
          },
        ],
      });

      final result = await client.complete(
        conn(AiProvider.openai, model: 'gpt-4o-mini'),
        system: 'S',
        user: 'U',
        maxTokens: 500,
      );

      expect(result.value, 'أهلاً');
      final body = seen.single.body!;
      expect(seen.single.path, '/chat/completions');
      expect(body['messages'], [
        {'role': 'system', 'content': 'S'},
        {'role': 'user', 'content': 'U'},
      ]);
      // OpenAI proper gets the new name; see the next test for the old one.
      expect(body['max_completion_tokens'], 500);
      expect(body.containsKey('max_tokens'), isFalse);
    });

    test('a compatible server gets max_tokens, the name it knows', () async {
      answer = json(200, {
        'choices': [
          {
            'message': {
              'content': [
                {'type': 'text', 'text': 'part one '},
                {'type': 'text', 'text': 'part two'},
              ],
            },
          },
        ],
      });

      final result = await client.complete(
        conn(AiProvider.compatible, model: 'llama'),
        system: 'S',
        user: 'U',
        maxTokens: 321,
      );

      expect(result.value, 'part one part two',
          reason: 'content as a list of parts is read too');
      expect(seen.single.body!['max_tokens'], 321);
      expect(seen.single.body!.containsKey('max_completion_tokens'), isFalse);
    });

    test('a compatible provider with no URL is refused before any socket', () async {
      final result = await client.listModels(
        const AiConnection(provider: AiProvider.compatible, apiKey: 'k'),
      );
      expect(result.failure!.kind, AiFailureKind.noBaseUrl);
      expect(seen, isEmpty);
    });
  });

  group('Gemini', () {
    test('lists only the models that can chat, without the models/ prefix', () async {
      answer = json(200, {
        'models': [
          {
            'name': 'models/gemini-2.5-flash',
            'displayName': 'Gemini 2.5 Flash',
            'supportedGenerationMethods': ['generateContent', 'countTokens'],
          },
          {
            'name': 'models/text-embedding-004',
            'displayName': 'Embedding',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
      });

      final result = await client.listModels(conn(AiProvider.gemini));

      expect(result.value!.map((m) => m.id), ['gemini-2.5-flash']);
      expect(seen.single.path, startsWith('/v1beta/models'));
      expect(seen.single.headers['x-goog-api-key'], 'sk-test');
    });

    test('posts generateContent with a system instruction and reads the parts', () async {
      answer = json(200, {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': 'نص '},
                {'text': 'الرد'},
              ],
              'role': 'model',
            },
          },
        ],
      });

      final result = await client.complete(
        conn(AiProvider.gemini, model: 'gemini-2.5-flash'),
        system: 'S',
        user: 'U',
        maxTokens: 900,
      );

      expect(result.value, 'نص الرد');
      final req = seen.single;
      expect(req.path, '/v1beta/models/gemini-2.5-flash:generateContent');
      expect(req.body!['system_instruction'], {
        'parts': [
          {'text': 'S'},
        ],
      });
      expect(req.body!['contents'], [
        {
          'role': 'user',
          'parts': [
            {'text': 'U'},
          ],
        },
      ]);
      expect(req.body!['generationConfig'], {'maxOutputTokens': 900});
    });
  });

  group('every failure is a sentence', () {
    test('no key is refused before any socket', () async {
      final result = await client.listModels(conn(AiProvider.anthropic, key: '  '));
      expect(result.failure!.kind, AiFailureKind.noKey);
      expect(seen, isEmpty);
    });

    test('401 is a bad key, with the service\'s own words attached', () async {
      answer = json(401, {
        'type': 'error',
        'error': {'type': 'authentication_error', 'message': 'invalid x-api-key'},
      });
      final result = await client.listModels(conn(AiProvider.anthropic));
      expect(result.failure!.kind, AiFailureKind.badKey);
      expect(result.failure!.detail, 'invalid x-api-key');
      expect(result.failure!.message, contains('المفتاح'));
    });

    test('403 is a bad key too', () async {
      answer = json(403, {'error': {'message': 'forbidden'}});
      final result = await client.listModels(conn(AiProvider.openai));
      expect(result.failure!.kind, AiFailureKind.badKey);
    });

    test('429 is the rate limit or the balance', () async {
      answer = json(429, {'error': {'message': 'rate limited'}});
      final result = await client.listModels(conn(AiProvider.gemini));
      expect(result.failure!.kind, AiFailureKind.rateLimited);
    });

    test('500 is the service, and carries its message', () async {
      answer = json(500, {'error': {'message': 'overloaded'}});
      final result = await client.complete(conn(AiProvider.anthropic), system: 's', user: 'u');
      expect(result.failure!.kind, AiFailureKind.service);
      expect(result.failure!.detail, 'overloaded');
    });

    test('a 404 for a model that does not exist says what the service said', () async {
      answer = json(404, {
        'error': {'message': 'The model `nope` does not exist'},
      });
      final result = await client.complete(
        conn(AiProvider.openai, model: 'nope'), system: 's', user: 'u');
      expect(result.failure!.kind, AiFailureKind.service);
      expect(result.failure!.detail, contains('nope'));
    });

    test('a 200 that is not JSON is the service, not a crash', () async {
      answer = (req) async {
        req.response
          ..statusCode = 200
          ..headers.contentType = ContentType.html
          ..write('<html>captive portal</html>');
        await req.response.close();
      };
      final result = await client.listModels(conn(AiProvider.anthropic));
      expect(result.failure!.kind, AiFailureKind.service);
    });

    test('a reply with no text is said plainly', () async {
      answer = json(200, {'content': []});
      final result = await client.complete(conn(AiProvider.anthropic), system: 's', user: 'u');
      expect(result.failure!.kind, AiFailureKind.emptyReply);
    });

    test('a host that is not there is the network', () async {
      // A port nothing listens on: the connection is refused at once.
      final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = dead.port;
      await dead.close();

      final result = await client.listModels(AiConnection(
        provider: AiProvider.anthropic,
        apiKey: 'k',
        baseUrl: 'http://127.0.0.1:$port',
      ));
      expect(result.failure!.kind, AiFailureKind.network);
      expect(result.failure!.message, contains('الإنترنت'));
    });

    test('a URL that is not one is the network, not a throw', () async {
      final result = await client.listModels(const AiConnection(
        provider: AiProvider.compatible,
        apiKey: 'k',
        baseUrl: 'not a url',
      ));
      expect(result.ok, isFalse);
      expect(result.failure!.kind, AiFailureKind.network);
    });

    test('the detail is trimmed, never the whole body', () async {
      answer = json(500, {'error': {'message': 'x' * 1000}});
      final result = await client.listModels(conn(AiProvider.anthropic));
      expect(result.failure!.detail!.length, lessThan(200));
    });
  });

  test('a trailing slash on the URL does not double up', () async {
    answer = json(200, {'data': []});
    await client.listModels(AiConnection(
      provider: AiProvider.compatible,
      apiKey: 'k',
      baseUrl: '${base()}/',
    ));
    expect(seen.single.path, '/models');
  });
}

class _Seen {
  const _Seen({
    required this.method,
    required this.path,
    required this.headers,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> headers;
  final Map<String, Object?>? body;
}
