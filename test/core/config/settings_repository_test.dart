import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/config/ai_config.dart';
import 'package:aitrans/core/config/settings_preferences_store.dart';
import 'package:aitrans/core/config/settings_repository.dart';
import 'package:aitrans/core/security/provider_credential_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads preferences and only the selected provider credential', () async {
    final preferences = _MemoryPreferencesStore(
      const ProviderPreferences(
        providerType: ProviderType.qwen,
        baseUrl: 'https://example.invalid/v1',
        model: 'test-model',
      ),
    );
    final credentials = _MemoryCredentialStore({
      ProviderType.openai: 'openai-test-key',
      ProviderType.qwen: 'qwen-test-key',
    });
    final repository = PersistentSettingsRepository(preferences, credentials);

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
        _MemoryPreferencesStore(
          const ProviderPreferences(providerType: ProviderType.ollama),
        ),
        _MemoryCredentialStore({ProviderType.openai: 'openai-test-key'}),
      );

      final draft = await repository.loadProviderDraft(ProviderType.openai);

      expect(draft.providerType, ProviderType.openai);
      expect(draft.apiKey, 'openai-test-key');
      expect(draft.baseUrl, isNull);
      expect(draft.model, isNull);
    },
  );

  test(
    'saves credentials separately and preserves explicit null overrides',
    () async {
      final preferences = _MemoryPreferencesStore(
        const ProviderPreferences(
          providerType: ProviderType.qwen,
          baseUrl: 'https://old.invalid/v1',
          model: 'old-model',
        ),
      );
      final credentials = _MemoryCredentialStore({
        ProviderType.qwen: 'old-test-key',
      });
      final repository = PersistentSettingsRepository(preferences, credentials);

      await repository.save(AIConfig(providerType: ProviderType.qwen));

      expect(
        preferences.value,
        const ProviderPreferences(providerType: ProviderType.qwen),
      );
      expect(credentials.values[ProviderType.qwen], isNull);
    },
  );

  test('propagates persistence failure to the caller', () async {
    final repository = PersistentSettingsRepository(
      _MemoryPreferencesStore(
        const ProviderPreferences(providerType: ProviderType.ollama),
        failWrites: true,
      ),
      _MemoryCredentialStore({}),
    );

    await expectLater(
      repository.save(AIConfig(providerType: ProviderType.qwen)),
      throwsA(isA<StateError>()),
    );
  });
}

class _MemoryPreferencesStore implements SettingsPreferencesStore {
  _MemoryPreferencesStore(this.value, {this.failWrites = false});

  ProviderPreferences value;
  final bool failWrites;

  @override
  Future<ProviderPreferences> load() async => value;

  @override
  Future<void> save(ProviderPreferences preferences) async {
    if (failWrites) throw StateError('synthetic preferences failure');
    value = preferences;
  }
}

class _MemoryCredentialStore implements ProviderCredentialStore {
  _MemoryCredentialStore(this.values);

  final Map<ProviderType, String> values;

  @override
  Future<String?> read(ProviderType providerType) async => values[providerType];

  @override
  Future<void> write(ProviderType providerType, String? credential) async {
    final normalized = credential?.trim() ?? '';
    if (normalized.isEmpty) {
      values.remove(providerType);
    } else {
      values[providerType] = normalized;
    }
  }
}
