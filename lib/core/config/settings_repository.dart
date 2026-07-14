import '../ai/provider_factory.dart';
import '../security/provider_credential_store.dart';
import 'ai_config.dart';
import 'settings_preferences_store.dart';

abstract interface class SettingsRepository {
  Future<AIConfig> load();

  Future<AIConfig> loadProviderDraft(ProviderType providerType);

  Future<void> save(AIConfig config);
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
}

class PersistentSettingsRepository implements SettingsRepository {
  PersistentSettingsRepository(this._preferences, this._credentials);

  final SettingsPreferencesStore _preferences;
  final ProviderCredentialStore _credentials;

  @override
  Future<AIConfig> load() async {
    final preferences = await _preferences.load();
    final apiKey = await _credentials.read(preferences.providerType);
    return preferences.toConfig(apiKey: apiKey);
  }

  @override
  Future<AIConfig> loadProviderDraft(ProviderType providerType) async {
    final apiKey = await _credentials.read(providerType);
    return AIConfig(providerType: providerType, apiKey: apiKey);
  }

  @override
  Future<void> save(AIConfig config) async {
    await _credentials.write(config.providerType, config.apiKey);
    await _preferences.save(ProviderPreferences.fromConfig(config));
  }
}
