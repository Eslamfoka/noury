import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nouri/data/db/nouri_database.dart';
import 'package:nouri/features/ai/ai_client.dart';
import 'package:nouri/features/ai/ai_key_store.dart';
import 'package:nouri/features/ai/ai_providers.dart';
import 'package:nouri/features/home/home_providers.dart';
import 'package:nouri/features/profile/profile_screen.dart';
import 'package:nouri/features/settings/settings_section_screen.dart';

import '../../support/harness.dart';

/// «ابني خطتي» with a key connected — the thing the button existed for.
///
/// The button's no-key path is in `profile_screen_test`; this is the other
/// half: press, call, sheet. And the join between the two — the no-key sheet
/// now leads to the settings page where the key goes.
void main() {
  late NouriDatabase db;
  late _FakeAiClient client;

  const tall = Size(420, 3000);

  Future<void> pump(WidgetTester t, {String? storedKey}) async {
    db = inMemoryDatabase(t);
    client = _FakeAiClient();
    await db.profileDao.get();
    await t.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        aiKeyStoreProvider.overrideWithValue(InMemoryAiKeyStore(storedKey)),
        aiClientProvider.overrideWithValue(client),
      ],
      child: testShell(const ProfileScreen()),
    ));
    await t.pumpAndSettle();
  }

  testWidgets('with a key, the press makes the one call and shows the plan',
      (t) async {
    await withLargeSurface(t, size: tall, () async {
      await pump(t, storedKey: 'sk-test');
      // Dated today, so the day survives the locked-window check; 16:30 is
      // after work on the default morning shift and before any bedtime.
      final today = DateTime.now();
      final iso = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      client.reply = '''
{"days":[{"date":"$iso","tasks":[{"id":"walk","at":"16:30","minutes":30}]}],
 "books":[{"title":"كتاب الأسبوع","why":"قريب من اهتماماتك"}],
 "note":"يوم هادي، مشي بعد العصر."}''';

      expect(find.byKey(const ValueKey('build-plan-needs-key')), findsNothing,
          reason: 'a key is there, so the button does not say it is missing');

      await t.tap(find.byKey(const ValueKey('build-my-plan')));
      await t.pumpAndSettle();

      expect(client.calls, 1, reason: 'one press, one call');
      expect(find.byKey(const ValueKey('plan-result-built')), findsOneWidget);
      expect(find.text('يوم هادي، مشي بعد العصر.'), findsOneWidget);
      expect(find.text('كتاب الأسبوع'), findsOneWidget);
      expect(find.textContaining('اقتراح'), findsOneWidget,
          reason: 'the sheet says the plan is proposed, not applied');
      expect(find.text('walk'), findsNothing,
          reason: 'titles, never ids');
    });
  });

  testWidgets('a failed call is one sentence and the day is untouched',
      (t) async {
    await withLargeSurface(t, size: tall, () async {
      await pump(t, storedKey: 'sk-test');
      client.failure = const AiFailure(AiFailureKind.network);

      await t.tap(find.byKey(const ValueKey('build-my-plan')));
      await t.pumpAndSettle();

      expect(find.byKey(const ValueKey('plan-result-failed')), findsOneWidget);
      expect(find.textContaining('الإنترنت'), findsOneWidget);
      expect(find.textContaining('يومك لسه زي ما هو'), findsOneWidget);
    });
  });

  testWidgets('without a key, nothing is sent and the sheet leads to settings',
      (t) async {
    await withLargeSurface(t, size: tall, () async {
      await pump(t);

      expect(find.byKey(const ValueKey('build-plan-needs-key')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('build-my-plan')));
      await t.pumpAndSettle();

      expect(client.calls, 0, reason: 'no key, no call');
      expect(find.byKey(const ValueKey('build-plan-not-ready')), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('build-plan-open-ai-settings')));
      await t.pumpAndSettle();

      expect(find.byType(SettingsSectionScreen), findsOneWidget);
      expect(find.text('CONNECT'), findsOneWidget,
          reason: 'it lands on the page with the CONNECT button');
    });
  });
}

class _FakeAiClient implements AiClient {
  String reply = '{"days":[]}';
  AiFailure? failure;
  int calls = 0;

  @override
  Future<AiResult<List<AiModel>>> listModels(AiConnection connection) async =>
      const AiResult.ok([]);

  @override
  Future<AiResult<String>> complete(
    AiConnection connection, {
    required String system,
    required String user,
    int maxTokens = 4096,
    bool json = false,
  }) async {
    calls++;
    if (failure != null) return AiResult.failed(failure!);
    return AiResult.ok(reply);
  }
}
