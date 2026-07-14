import '../ai/provider_factory.dart';
import 'ai_config.dart';
import 'settings_preferences_store.dart';

abstract interface class SettingsPersistenceStore {
  Future<ProviderPreferences> loadPreferences();

  Future<String?> readCredential(ProviderType providerType);

  Future<void> saveConfig(AIConfig config);

  Future<void> resetCredentials();
}

abstract interface class SettingsRepository {
  Future<AIConfig> load();

  Future<AIConfig> loadProviderDraft(ProviderType providerType);

  Future<void> save(AIConfig config);

  Future<void> resetCredentials();
}

class UnavailableSettingsRepository implements SettingsRepository {
  const UnavailableSettingsRepository();

  StateError _error() => StateError('Settings storage is unavailable.');

  @override
  Future<AIConfig> load() => Future.error(_error());

  @override
  Future<AIConfig> loadProviderDraft(ProviderType providerType) {
    return Future.error(_error());
  }

  @override
  Future<void> save(AIConfig config) => Future.error(_error());

  @override
  Future<void> resetCredentials() => Future.error(_error());
}

class PersistentSettingsRepository implements SettingsRepository {
  PersistentSettingsRepository(this._store);

  final SettingsPersistenceStore _store;

  @override
  Future<AIConfig> load() async {
    final preferences = await _store.loadPreferences();
    final apiKey = await _store.readCredential(preferences.providerType);
    return preferences.toConfig(apiKey: apiKey);
  }

  @override
  Future<AIConfig> loadProviderDraft(ProviderType providerType) async {
    final apiKey = await _store.readCredential(providerType);
    return AIConfig(providerType: providerType, apiKey: apiKey);
  }

  @override
  Future<void> save(AIConfig config) async {
    await _store.saveConfig(config);
  }

  @override
  Future<void> resetCredentials() => _store.resetCredentials();
}
