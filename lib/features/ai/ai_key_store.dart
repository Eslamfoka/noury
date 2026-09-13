import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the API key lives.
///
/// The brief, §6: *"Secure the API key with `flutter_secure_storage`. Never
/// log it, never send it anywhere but the service."* So the key is not a
/// settings column — a database file copied off the phone, or a debug dump
/// of the settings row, must not carry it. It sits in the platform keystore
/// under one name, and the settings row records only that CONNECT worked.
///
/// An interface, so the settings panel and the plan button can be tested
/// with the in-memory store below rather than a platform channel.
abstract interface class AiKeyStore {
  /// The stored key, or null if none — including when the keystore itself
  /// cannot be read, which happens on some devices after an OS update. That
  /// case reads as "no key": the user pastes it again, and nothing is lost
  /// but a paste.
  Future<String?> read();

  Future<void> write(String key);

  Future<void> clear();
}

/// The real one, over the platform keystore.
class SecureAiKeyStore implements AiKeyStore {
  SecureAiKeyStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// One key, one name. Versioned like a channel id, so a future change of
  /// cipher or shape can move to a new name and leave the old one to expire.
  static const keyName = 'ai_api_key_v1';

  @override
  Future<String?> read() async {
    try {
      final value = await _storage.read(key: keyName);
      return value == null || value.trim().isEmpty ? null : value;
    } catch (_) {
      // A keystore that will not decrypt is indistinguishable, for every
      // purpose that matters here, from one that holds nothing.
      return null;
    }
  }

  @override
  Future<void> write(String key) => _storage.write(key: keyName, value: key.trim());

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: keyName);
    } catch (_) {
      // Nothing to clear, or nothing that can be. Either way it is gone.
    }
  }
}

/// For tests, and the default before `main()` installs the secure one.
class InMemoryAiKeyStore implements AiKeyStore {
  InMemoryAiKeyStore([this._key]);

  String? _key;

  @override
  Future<String?> read() async => _key;

  @override
  Future<void> write(String key) async => _key = key.trim();

  @override
  Future<void> clear() async => _key = null;
}
