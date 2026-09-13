import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../home/home_providers.dart';
import 'ai_client.dart';
import 'ai_connection_controller.dart';
import 'ai_http_client.dart';
import 'ai_key_store.dart';
import 'ai_provider.dart';

/// The keystore. **Overridden in `main()` with [SecureAiKeyStore]**; the
/// default is the in-memory one so widget tests, which have no platform
/// channel, can render the settings panel and press its button.
final aiKeyStoreProvider = Provider<AiKeyStore>((ref) => InMemoryAiKeyStore());

/// The one client that opens sockets. Overridden in tests with a fake, so
/// no test ever reaches the network — `no_network_test` checks that the
/// real one is imported from exactly one place.
final aiClientProvider = Provider<AiClient>((ref) => HttpAiClient());

final aiConnectionControllerProvider = Provider<AiConnectionController>(
  (ref) => AiConnectionController(
    db: ref.watch(databaseProvider),
    keys: ref.watch(aiKeyStoreProvider),
    client: ref.watch(aiClientProvider),
  ),
);

/// The stored key, or null. Invalidated by the panel after CONNECT and after
/// «امسح المفتاح», like every other FutureProvider in the app.
final aiStoredKeyProvider = FutureProvider<String?>(
  (ref) => ref.watch(aiKeyStoreProvider).read(),
);

/// Everything a call needs, or null when there is no key to make one with.
///
/// Assembled fresh from the settings row and the keystore, so a key cleared
/// in settings is gone from the very next «ابني خطتي».
final aiConnectionProvider = FutureProvider<AiConnection?>((ref) async {
  final settings = await ref.watch(settingsProvider.future);
  final key = await ref.watch(aiStoredKeyProvider.future);
  if (key == null) return null;

  return AiConnection(
    provider: AiProvider.fromName(settings.aiProvider),
    apiKey: key,
    model: settings.aiModel,
    baseUrl: settings.aiBaseUrl,
  );
});
