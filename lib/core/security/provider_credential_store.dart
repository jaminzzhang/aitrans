import '../ai/provider_factory.dart';

abstract interface class SecureKeyValueStore {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

abstract interface class ProviderCredentialStore {
  Future<String?> read(ProviderType providerType);

  Future<void> write(ProviderType providerType, String? credential);
}

class SecureProviderCredentialStore implements ProviderCredentialStore {
  SecureProviderCredentialStore(this._store);

  final SecureKeyValueStore _store;

  @override
  Future<String?> read(ProviderType providerType) {
    return _store.read(_keyFor(providerType));
  }

  @override
  Future<void> write(ProviderType providerType, String? credential) {
    final normalized = credential?.trim() ?? '';
    final key = _keyFor(providerType);
    if (normalized.isEmpty) return _store.delete(key);
    return _store.write(key, normalized);
  }

  static String _keyFor(ProviderType providerType) {
    return 'aitrans.provider.${providerType.name}.apiKey';
  }
}
