import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/config/ai_config.dart';
import 'package:aitrans/core/config/settings_preferences_store.dart';
import 'package:aitrans/core/config/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads preferences and only the selected provider credential', () async {
    final store = _MemorySettingsStore(
      const ProviderPreferences(
        providerType: ProviderType.qwen,
        baseUrl: 'https://example.invalid/v1',
        model: 'test-model',
      ),
      {
        ProviderType.openai: 'openai-test-key',
        ProviderType.qwen: 'qwen-test-key',
      },
    );
    final repository = PersistentSettingsRepository(store);

    final config = await repository.load();

    expect(config.providerType, ProviderType.qwen);
    expect(config.apiKey, 'qwen-test-key');
    expect(config.baseUrl, 'https://example.invalid/v1');
    expect(config.model, 'test-model');
  });

  test(
    'loads a provider draft with its isolated credential and no overrides',
    () async {
      final repository = PersistentSettingsRepository(
        _MemorySettingsStore(
          const ProviderPreferences(providerType: ProviderType.ollama),
          {ProviderType.openai: 'openai-test-key'},
        ),
      );

      final draft = await repository.loadProviderDraft(ProviderType.openai);

      expect(draft.providerType, ProviderType.openai);
      expect(draft.apiKey, 'openai-test-key');
      expect(draft.baseUrl, isNull);
      expect(draft.model, isNull);
    },
  );

  test('saves preferences and credentials as one store operation', () async {
    final store = _MemorySettingsStore(
      const ProviderPreferences(
        providerType: ProviderType.qwen,
        baseUrl: 'https://old.invalid/v1',
        model: 'old-model',
      ),
      {ProviderType.qwen: 'old-test-key'},
    );
    final repository = PersistentSettingsRepository(store);

    await repository.save(AIConfig(providerType: ProviderType.qwen));

    expect(
      store.preferences,
      const ProviderPreferences(providerType: ProviderType.qwen),
    );
    expect(store.credentials[ProviderType.qwen], isNull);
    expect(store.saveCount, 1);
  });

  test(
    'failed atomic save leaves both preferences and credential unchanged',
    () async {
      const originalPreferences = ProviderPreferences(
        providerType: ProviderType.qwen,
        model: 'old-model',
      );
      final store = _MemorySettingsStore(originalPreferences, {
        ProviderType.qwen: 'old-test-key',
      }, failSaves: true);
      final repository = PersistentSettingsRepository(store);

      await expectLater(
        repository.save(
          AIConfig(
            providerType: ProviderType.qwen,
            apiKey: 'new-test-key',
            model: 'new-model',
          ),
        ),
        throwsA(isA<StateError>()),
      );

      expect(store.preferences, originalPreferences);
      expect(store.credentials[ProviderType.qwen], 'old-test-key');
    },
  );

  test('reset removes all credentials but preserves preferences', () async {
    const preferences = ProviderPreferences(providerType: ProviderType.qwen);
    final store = _MemorySettingsStore(preferences, {
      ProviderType.openai: 'openai-test-key',
      ProviderType.qwen: 'qwen-test-key',
    });
    final repository = PersistentSettingsRepository(store);

    await repository.resetCredentials();

    expect(store.preferences, preferences);
    expect(store.credentials, isEmpty);
  });
}

class _MemorySettingsStore implements SettingsPersistenceStore {
  _MemorySettingsStore(
    this.preferences,
    Map<ProviderType, String> credentials, {
    this.failSaves = false,
  }) : credentials = Map<ProviderType, String>.from(credentials);

  ProviderPreferences preferences;
  final Map<ProviderType, String> credentials;
  final bool failSaves;
  int saveCount = 0;

  @override
  Future<ProviderPreferences> loadPreferences() async => preferences;

  @override
  Future<String?> readCredential(ProviderType providerType) async {
    return credentials[providerType];
  }

  @override
  Future<void> saveConfig(AIConfig config) async {
    saveCount++;
    if (failSaves) throw StateError('synthetic atomic settings failure');
    final normalized = config.apiKey?.trim() ?? '';
    preferences = ProviderPreferences.fromConfig(config);
    if (normalized.isEmpty) {
      credentials.remove(config.providerType);
    } else {
      credentials[config.providerType] = normalized;
    }
  }

  @override
  Future<void> resetCredentials() async => credentials.clear();
}
