import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/ai/ai_client.dart';
import 'package:nouri/features/ai/ai_connection_panel.dart';
import 'package:nouri/features/ai/ai_key_store.dart';
import 'package:nouri/features/ai/ai_provider.dart';
import 'package:nouri/features/ai/ai_providers.dart';
import 'package:nouri/features/home/home_providers.dart';
import 'package:nouri/features/settings/settings_section_screen.dart';
import 'package:nouri/features/settings/settings_sections.dart';

import '../../support/harness.dart';

/// The CONNECT part, as the user asked for it on 13 September 2026:
///
///   «عايزك تبني الجزء الخاص ب CONNECT ومش لازم كلود يحطه في الخانة ويدوس
///    عادي ai بس اي»
///
/// A key goes in the field, CONNECT is pressed, and the service says yes or
/// no. What these tests hold: the key is kept only after a yes; the status
/// row says what is true; a no is a sentence and not a crash; and the key
/// never appears on screen.
void main() {
  late NouriDatabase db;
  late InMemoryAiKeyStore keys;
  late _FakeAiClient client;

  Future<void> pump(WidgetTester t) async {
    db = inMemoryDatabase(t);
    keys = InMemoryAiKeyStore();
    client = _FakeAiClient();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          aiKeyStoreProvider.overrideWithValue(keys),
          aiClientProvider.overrideWithValue(client),
        ],
        child: testShell(
          const SettingsSectionScreen(section: SettingsSection.ai),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester t, Finder target) async {
    await t.scrollUntilVisible(target, 200,
        scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  }

  testWidgets('opens unconnected, on Claude, with CONNECT and no key shown',
      (t) async {
    await withLargeSurface(t, () async {
      await pump(t);

      expect(find.text('مش متصل'), findsOneWidget);
      expect(find.text('CONNECT'), findsOneWidget);
      expect(find.byType(AiConnectionPanel), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-disconnect')), findsNothing,
          reason: 'nothing to clear yet');

      // The four services, Claude selected by default.
      for (final p in AiProvider.values) {
        expect(find.byKey(ValueKey('ai-provider-${p.name}')), findsOneWidget);
      }
    });
  });

  testWidgets('CONNECT with a key the service accepts stores it and says so',
      (t) async {
    await withLargeSurface(t, () async {
      await pump(t);
      client.models = const [
        AiModel(id: 'claude-haiku-4-5', displayName: 'Claude Haiku 4.5'),
        AiModel(id: 'claude-opus-5', displayName: 'Claude Opus 5'),
      ];

      await t.enterText(find.byKey(const ValueKey('ai-key-field')), 'sk-ant-abc');
      await scrollTo(t, find.byKey(const ValueKey('ai-connect')));
      await t.tap(find.byKey(const ValueKey('ai-connect')));
      await t.pumpAndSettle();

      expect(await keys.read(), 'sk-ant-abc');
      expect(client.lastConnection!.provider, AiProvider.anthropic);
      expect(client.lastConnection!.apiKey, 'sk-ant-abc');

      final s = await db.settingsDao.get();
      expect(s.aiProvider, 'anthropic');
      expect(s.aiConnectedAt, isNotNull);

      expect(find.text('متصل'), findsOneWidget);
      expect(find.textContaining('المفتاح شغّال'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-disconnect')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-pick-model')), findsOneWidget,
          reason: 'the list the service returned is now offered');
    });
  });

  testWidgets('a key the service refuses is not kept, and the reason is said',
      (t) async {
    await withLargeSurface(t, () async {
      await pump(t);
      client.failure = const AiFailure(AiFailureKind.badKey, detail: 'invalid x-api-key');

      await t.enterText(find.byKey(const ValueKey('ai-key-field')), 'sk-wrong');
      await scrollTo(t, find.byKey(const ValueKey('ai-connect')));
      await t.tap(find.byKey(const ValueKey('ai-connect')));
      await t.pumpAndSettle();

      expect(await keys.read(), isNull, reason: 'a refused key is not stored');
      expect((await db.settingsDao.get()).aiConnectedAt, isNull);
      expect(find.text('مش متصل'), findsOneWidget);
      expect(find.textContaining('مش قابلة المفتاح'), findsOneWidget);
      expect(find.textContaining('invalid x-api-key'), findsOneWidget,
          reason: 'the service\'s own words, for the bug report');

      // Never red. The note is attention-orange like every other "fix this".
      final note = t.widget<Text>(find.byKey(const ValueKey('ai-note')));
      final c = note.style!.color!;
      expect(c.r > 0.75 && c.g < 0.4 && c.b < 0.4, isFalse);
    });
  });

  testWidgets('no internet is said plainly and stores nothing', (t) async {
    await withLargeSurface(t, () async {
      await pump(t);
      client.failure = const AiFailure(AiFailureKind.network);

      await t.enterText(find.byKey(const ValueKey('ai-key-field')), 'sk-x');
      await scrollTo(t, find.byKey(const ValueKey('ai-connect')));
      await t.tap(find.byKey(const ValueKey('ai-connect')));
      await t.pumpAndSettle();

      expect(await keys.read(), isNull);
      expect(find.textContaining('الإنترنت'), findsOneWidget);
    });
  });

  testWidgets('the key is obscured, and the field empties once it is stored',
      (t) async {
    await withLargeSurface(t, () async {
      await pump(t);

      final field = t.widget<TextField>(find.byKey(const ValueKey('ai-key-field')));
      expect(field.obscureText, isTrue);

      await t.enterText(find.byKey(const ValueKey('ai-key-field')), 'sk-secret');
      await scrollTo(t, find.byKey(const ValueKey('ai-connect')));
      await t.tap(find.byKey(const ValueKey('ai-connect')));
      await t.pumpAndSettle();

      final after = t.widget<TextField>(find.byKey(const ValueKey('ai-key-field')));
      expect(after.controller!.text, isEmpty,
          reason: 'a stored key is a fact, not a string to display');
      expect(find.text('sk-secret'), findsNothing);
    });
  });

  testWidgets('CONNECT with the field empty reuses the stored key', (t) async {
    await withLargeSurface(t, () async {
      await pump(t);
      await keys.write('sk-stored');

      // Switch provider, leave the key field empty, press.
      await t.tap(find.byKey(const ValueKey('ai-provider-openai')));
      await t.pumpAndSettle();
      await scrollTo(t, find.byKey(const ValueKey('ai-connect')));
      await t.tap(find.byKey(const ValueKey('ai-connect')));
      await t.pumpAndSettle();

      expect(client.lastConnection!.apiKey, 'sk-stored');
      expect(client.lastConnection!.provider, AiProvider.openai);
      expect((await db.settingsDao.get()).aiProvider, 'openai');
    });
  });

  testWidgets('the compatible provider asks for a URL and sends it', (t) async {
    await withLargeSurface(t, () async {
      await pump(t);

      expect(find.byKey(const ValueKey('ai-url-field')), findsNothing,
          reason: 'the named services have fixed hosts');

      await t.tap(find.byKey(const ValueKey('ai-provider-compatible')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-url-field')), findsOneWidget);

      await t.enterText(find.byKey(const ValueKey('ai-url-field')), 'http://127.0.0.1:11434/v1/');
      await t.enterText(find.byKey(const ValueKey('ai-key-field')), 'k');
      await t.enterText(find.byKey(const ValueKey('ai-model-field')), 'llama3');
      await scrollTo(t, find.byKey(const ValueKey('ai-connect')));
      await t.tap(find.byKey(const ValueKey('ai-connect')));
      await t.pumpAndSettle();

      expect(client.lastConnection!.baseUrl, 'http://127.0.0.1:11434/v1');
      expect(client.lastConnection!.model, 'llama3');
      final s = await db.settingsDao.get();
      expect(s.aiBaseUrl, 'http://127.0.0.1:11434/v1/');
      expect(s.aiModel, 'llama3');
    });
  });

  testWidgets('picking a model from the list writes it', (t) async {
    await withLargeSurface(t, () async {
      await pump(t);
      client.models = const [
        AiModel(id: 'claude-haiku-4-5'),
        AiModel(id: 'claude-opus-5', displayName: 'Claude Opus 5'),
      ];
      await t.enterText(find.byKey(const ValueKey('ai-key-field')), 'k');
      await scrollTo(t, find.byKey(const ValueKey('ai-connect')));
      await t.tap(find.byKey(const ValueKey('ai-connect')));
      await t.pumpAndSettle();

      await t.tap(find.byKey(const ValueKey('ai-pick-model')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('ai-model-claude-opus-5')));
      await t.pumpAndSettle();

      expect((await db.settingsDao.get()).aiModel, 'claude-opus-5');
      final field = t.widget<TextField>(find.byKey(const ValueKey('ai-model-field')));
      expect(field.controller!.text, 'claude-opus-5');
    });
  });

  testWidgets('«امسح المفتاح» forgets the key and the connection', (t) async {
    await withLargeSurface(t, () async {
      await pump(t);
      await t.enterText(find.byKey(const ValueKey('ai-key-field')), 'k');
      await scrollTo(t, find.byKey(const ValueKey('ai-connect')));
      await t.tap(find.byKey(const ValueKey('ai-connect')));
      await t.pumpAndSettle();
      expect(await keys.read(), 'k');

      await scrollTo(t, find.byKey(const ValueKey('ai-disconnect')));
      await t.tap(find.byKey(const ValueKey('ai-disconnect')));
      await t.pumpAndSettle();

      expect(await keys.read(), isNull);
      expect((await db.settingsDao.get()).aiConnectedAt, isNull);
      expect(find.text('مش متصل'), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-disconnect')), findsNothing);
    });
  });

  testWidgets('nothing on the screen blames the user', (t) async {
    await withLargeSurface(t, () async {
      await pump(t);
      client.failure = const AiFailure(AiFailureKind.badKey);
      await t.enterText(find.byKey(const ValueKey('ai-key-field')), 'k');
      await scrollTo(t, find.byKey(const ValueKey('ai-connect')));
      await t.tap(find.byKey(const ValueKey('ai-connect')));
      await t.pumpAndSettle();

      for (final w in ['غلط', 'فشل', 'خطأ منك', 'ضيعت']) {
        expect(find.textContaining(w), findsNothing, reason: w);
      }
    });
  });
}

/// A service that answers what it is told to, and remembers what it was asked.
class _FakeAiClient implements AiClient {
  List<AiModel> models = const [AiModel(id: 'm')];
  AiFailure? failure;
  AiConnection? lastConnection;

  @override
  Future<AiResult<List<AiModel>>> listModels(AiConnection connection) async {
    lastConnection = connection;
    if (failure != null) return AiResult.failed(failure!);
    return AiResult.ok(models);
  }

  @override
  Future<AiResult<String>> complete(
    AiConnection connection, {
    required String system,
    required String user,
    int maxTokens = 4096,
  }) async {
    lastConnection = connection;
    if (failure != null) return AiResult.failed(failure!);
    return const AiResult.ok('{}');
  }
}
