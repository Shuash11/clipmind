import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureKeyStore {
  final FlutterSecureStorage _storage;

  static const _keyPrefix = 'clipmind_';

  SecureKeyStore() : _storage = const FlutterSecureStorage();

  // ignore: unnecessary_brace_in_string_interps
  String _keyFor(String provider) => '${_keyPrefix}${provider}_api_key';

  Future<void> saveApiKey(String provider, String key) async {
    await _storage.write(key: _keyFor(provider), value: key);
  }

  Future<String?> readApiKey(String provider) async {
    return await _storage.read(key: _keyFor(provider));
  }

  Future<void> deleteApiKey(String provider) async {
    await _storage.delete(key: _keyFor(provider));
  }

  Future<bool> hasApiKey(String provider) async {
    final key = await readApiKey(provider);
    return key != null && key.isNotEmpty;
  }

  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
