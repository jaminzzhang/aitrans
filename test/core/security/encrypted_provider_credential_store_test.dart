import 'dart:convert';
import 'dart:io';

import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/config/ai_config.dart';
import 'package:aitrans/core/security/encrypted_provider_credential_store.dart';
import 'package:aitrans/core/security/local_master_key_store.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeKeyStore implements MasterKeyProvider {
  _FakeKeyStore(this.key, {this.failFirstLoad = false});

  List<int>? key;
  final bool failFirstLoad;
  int loadCount = 0;
  int createCount = 0;

  @override
  Future<SecretKey?> loadExisting() async {
    loadCount++;
    if (failFirstLoad && loadCount == 1) {
      throw const MasterKeyUnavailableException();
    }
    final value = key;
    return value == null ? null : SecretKey(value);
  }

  @override
  Future<SecretKey> create() async {
    createCount++;
    final value = key ??= List<int>.filled(32, 99);
    return SecretKey(value);
  }

  @override
  Future<void> reset() async => key = null;
}

void main() {
  late Directory directory;
  late Box<dynamic> box;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aitrans-credentials-');
    Hive.init(directory.path);
    box = await Hive.openBox<dynamic>('credentials');
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test('stores only authenticated ciphertext and reloads it', () async {
    final store = EncryptedProviderCredentialStore(
      box,
      _FakeKeyStore(List<int>.filled(32, 7)),
    );

    await store.write(ProviderType.openai, 'synthetic-openai-key');

    final raw = box.get(EncryptedProviderCredentialStore.credentialsKey);
    expect(jsonEncode(raw), isNot(contains('synthetic-openai-key')));
    expect(
      await EncryptedProviderCredentialStore(
        box,
        _FakeKeyStore(List<int>.filled(32, 7)),
      ).read(ProviderType.openai),
      'synthetic-openai-key',
    );
  });

  test('isolates providers and deletes only the selected credential', () async {
    final store = EncryptedProviderCredentialStore(
      box,
      _FakeKeyStore(List<int>.filled(32, 8)),
    );
    await store.write(ProviderType.openai, 'openai-test-key');
    await store.write(ProviderType.qwen, 'qwen-test-key');

    await store.write(ProviderType.openai, null);

    expect(await store.read(ProviderType.openai), isNull);
    expect(await store.read(ProviderType.qwen), 'qwen-test-key');
  });

  test('rejects tampered ciphertext', () async {
    final store = EncryptedProviderCredentialStore(
      box,
      _FakeKeyStore(List<int>.filled(32, 9)),
    );
    await store.write(ProviderType.openai, 'key-to-tamper');
    final state = Map<String, dynamic>.from(
      (box.get(EncryptedProviderCredentialStore.settingsStateKey) as Map)
          .cast<String, dynamic>(),
    );
    final raw = Map<String, dynamic>.from(
      (state['credentials'] as Map).cast<String, dynamic>(),
    );
    final entry = Map<String, dynamic>.from(
      (raw[ProviderType.openai.name] as Map).cast<String, dynamic>(),
    );
    final cipherText = base64Decode(entry['cipherText'] as String);
    cipherText[0] ^= 1;
    entry['cipherText'] = base64Encode(cipherText);
    raw[ProviderType.openai.name] = entry;
    state['credentials'] = raw;
    await box.put(EncryptedProviderCredentialStore.settingsStateKey, state);

    expect(() => store.read(ProviderType.openai), throwsA(isA<StateError>()));
  });

  test('rejects moving ciphertext to another provider', () async {
    final store = EncryptedProviderCredentialStore(
      box,
      _FakeKeyStore(List<int>.filled(32, 10)),
    );
    await store.write(ProviderType.openai, 'provider-bound-key');
    final state = Map<String, dynamic>.from(
      (box.get(EncryptedProviderCredentialStore.settingsStateKey) as Map)
          .cast<String, dynamic>(),
    );
    final records = Map<String, dynamic>.from(
      (state['credentials'] as Map).cast<String, dynamic>(),
    );
    records[ProviderType.qwen.name] = records.remove(ProviderType.openai.name);
    state['credentials'] = records;
    await box.put(EncryptedProviderCredentialStore.settingsStateKey, state);

    expect(() => store.read(ProviderType.qwen), throwsA(isA<StateError>()));
  });

  test(
    'does not create a replacement key when ciphertext already exists',
    () async {
      final originalKey = _FakeKeyStore(List<int>.filled(32, 11));
      final store = EncryptedProviderCredentialStore(box, originalKey);
      await store.write(ProviderType.openai, 'existing-key');
      final missingKey = _FakeKeyStore(null);

      await expectLater(
        EncryptedProviderCredentialStore(
          box,
          missingKey,
        ).read(ProviderType.openai),
        throwsA(isA<MasterKeyMissingException>()),
      );
      expect(missingKey.createCount, 0);
    },
  );

  test('retries a transient key load failure in the same store', () async {
    final keyStore = _FakeKeyStore(
      List<int>.filled(32, 12),
      failFirstLoad: true,
    );
    final store = EncryptedProviderCredentialStore(box, keyStore);

    await expectLater(
      store.write(ProviderType.openai, 'retry-key'),
      throwsA(isA<MasterKeyUnavailableException>()),
    );
    await store.write(ProviderType.openai, 'retry-key');

    expect(await store.read(ProviderType.openai), 'retry-key');
    expect(keyStore.loadCount, 2);
  });

  test('rejects an envelope with a different key identifier', () async {
    final store = EncryptedProviderCredentialStore(
      box,
      _FakeKeyStore(List<int>.filled(32, 13)),
    );
    await store.write(ProviderType.openai, 'key-id-bound');
    final state = Map<String, dynamic>.from(
      (box.get(EncryptedProviderCredentialStore.settingsStateKey) as Map)
          .cast<String, dynamic>(),
    );
    final credentials = Map<String, dynamic>.from(
      (state['credentials'] as Map).cast<String, dynamic>(),
    );
    final entry = Map<String, dynamic>.from(
      (credentials[ProviderType.openai.persistenceId] as Map)
          .cast<String, dynamic>(),
    );
    entry['keyId'] = 'different-key';
    credentials[ProviderType.openai.persistenceId] = entry;
    state['credentials'] = credentials;
    await box.put(EncryptedProviderCredentialStore.settingsStateKey, state);

    await expectLater(
      EncryptedProviderCredentialStore(
        box,
        _FakeKeyStore(List<int>.filled(32, 13)),
      ).read(ProviderType.openai),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'commits preferences and encrypted credential in one state record',
    () async {
      final store = EncryptedProviderCredentialStore(
        box,
        _FakeKeyStore(List<int>.filled(32, 14)),
      );

      await store.saveConfig(
        AIConfig(
          providerType: ProviderType.qwen,
          apiKey: 'atomic-key',
          model: 'atomic-model',
        ),
      );

      final state = box.get(EncryptedProviderCredentialStore.settingsStateKey);
      expect(state, isA<Map>());
      expect((state as Map)['preferences'], isA<Map>());
      expect(state['credentials'], isA<Map>());
      expect(await store.read(ProviderType.qwen), 'atomic-key');
      expect((await store.loadPreferences()).model, 'atomic-model');
    },
  );

  test(
    'serializes concurrent writes without losing another provider',
    () async {
      final store = EncryptedProviderCredentialStore(
        box,
        _FakeKeyStore(List<int>.filled(32, 15)),
      );

      await Future.wait([
        store.write(ProviderType.openai, 'openai-concurrent-key'),
        store.write(ProviderType.qwen, 'qwen-concurrent-key'),
      ]);

      expect(await store.read(ProviderType.openai), 'openai-concurrent-key');
      expect(await store.read(ProviderType.qwen), 'qwen-concurrent-key');
    },
  );

  test(
    'confirmed reset atomically replaces all credential envelopes',
    () async {
      final keyStore = _FakeKeyStore(List<int>.filled(32, 16));
      final store = EncryptedProviderCredentialStore(box, keyStore);
      await store.write(ProviderType.openai, 'openai-reset-key');
      await store.write(ProviderType.qwen, 'qwen-reset-key');

      await store.resetCredentials();

      expect(await store.read(ProviderType.openai), isNull);
      expect(await store.read(ProviderType.qwen), isNull);
      final state = box.get(EncryptedProviderCredentialStore.settingsStateKey);
      expect((state as Map)['credentials'], isEmpty);
      expect(keyStore.key, isNull);
    },
  );
}
