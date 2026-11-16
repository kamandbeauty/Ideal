import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credentials stored in the platform keystore, never in SQLite or source.
class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _apiKeyEntry = 'javid_ai_api_key';

  final FlutterSecureStorage _storage;

  Future<String?> readApiKey() async {
    try {
      return await _storage.read(key: _apiKeyEntry);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeApiKey(String value) =>
      _storage.write(key: _apiKeyEntry, value: value);

  Future<void> deleteApiKey() => _storage.delete(key: _apiKeyEntry);
}

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());
