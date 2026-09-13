import 'package:drift/drift.dart' show Value;

import '../../data/db/nouri_database.dart';
import 'ai_client.dart';
import 'ai_key_store.dart';
import 'ai_provider.dart';

/// What CONNECT does, and what «امسح المفتاح» undoes.
///
/// One press, one round trip, and a write only on success. The order is the
/// point: the key is stored **after** the service has accepted it, so a key
/// that failed is never the one the app carries, and the settings row's
/// `aiConnectedAt` is the moment it was seen to work rather than the moment
/// it was typed.
///
/// Verification is [AiClient.listModels], not a chat call: it proves the key
/// and the URL without spending a token, and it brings back the names the
/// user can pick a model from. Cost discipline is the brief's rule and this
/// is where it starts.
class AiConnectionController {
  AiConnectionController({
    required this.db,
    required this.keys,
    required this.client,
  });

  final NouriDatabase db;
  final AiKeyStore keys;
  final AiClient client;

  /// Tries the key against the service; keeps it only if the service does.
  ///
  /// [apiKey] empty means "the one already stored" — so a user who changed
  /// only the provider or the model can press CONNECT again without pasting
  /// the key a second time.
  Future<AiResult<List<AiModel>>> connect({
    required AiProvider provider,
    required String apiKey,
    required String model,
    required String baseUrl,
  }) async {
    final key = apiKey.trim().isEmpty ? (await keys.read() ?? '') : apiKey;

    final connection = AiConnection(
      provider: provider,
      apiKey: key,
      model: model,
      baseUrl: baseUrl,
    );

    final result = await client.listModels(connection);
    if (!result.ok) return result;

    await keys.write(key);
    await db.settingsDao.update(SettingsRowsCompanion(
      aiProvider: Value(provider.name),
      aiModel: Value(model.trim()),
      aiBaseUrl: Value(provider.needsBaseUrl ? baseUrl.trim() : ''),
      aiConnectedAt: Value(DateTime.now()),
    ));
    return result;
  }

  /// Changes the model without a round trip. It was picked from the list the
  /// service itself returned, or typed on purpose; either way there is
  /// nothing to verify that a call will not verify better.
  Future<void> updateModel(String model) => db.settingsDao.update(
        SettingsRowsCompanion(aiModel: Value(model.trim())),
      );

  /// Forgets the key. The provider and model stay, so pasting a new key is
  /// one field and one press.
  Future<void> disconnect() async {
    await keys.clear();
    await db.settingsDao.update(const SettingsRowsCompanion(
      aiConnectedAt: Value(null),
    ));
  }
}
