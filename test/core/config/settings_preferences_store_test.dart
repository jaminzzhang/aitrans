import 'dart:io';

import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/config/settings_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDirectory;
  late Box<dynamic> box;
  late HiveSettingsPreferencesStore store;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'aitrans-settings-test-',
    );
    Hive.init(tempDirectory.path);
    box = await Hive.openBox<dynamic>('settings_preferences');
    store = HiveSettingsPreferencesStore(box);
  });

  tearDown(() async {
    await Hive.close();
    await tempDirectory.delete(recursive: true);
  });

  test(
    'restores non-secret provider preferences without an API key field',
    () async {
      const preferences = ProviderPreferences(
        providerType: ProviderType.qwen,
        baseUrl: 'https://example.invalid/v1',
        model: 'test-model',
      );

      await store.save(preferences);
      final restored = await HiveSettingsPreferencesStore(box).load();

      expect(restored, preferences);
      final persisted = box.get(HiveSettingsPreferencesStore.preferencesKey);
      expect(persisted, isA<Map>());
      expect((persisted as Map).containsKey('apiKey'), isFalse);
    },
  );

  test(
    'saving null overrides clears an earlier custom endpoint and model',
    () async {
      await store.save(
        const ProviderPreferences(
          providerType: ProviderType.qwen,
          baseUrl: 'https://example.invalid/v1',
          model: 'test-model',
        ),
      );

      await store.save(
        const ProviderPreferences(providerType: ProviderType.qwen),
      );

      expect(
        await HiveSettingsPreferencesStore(box).load(),
        const ProviderPreferences(providerType: ProviderType.qwen),
      );
    },
  );

  test('malformed persisted data falls back to Ollama defaults', () async {
    await box.put(HiveSettingsPreferencesStore.preferencesKey, {
      'schemaVersion': 1,
      'providerType': 'not-a-provider',
      'baseUrl': 42,
    });

    expect(
      await store.load(),
      const ProviderPreferences(providerType: ProviderType.ollama),
    );
  });
}
