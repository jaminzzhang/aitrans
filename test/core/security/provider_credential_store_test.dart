import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/security/provider_credential_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isolates credentials by stable provider ID', () async {
    final keyValueStore = _MemorySecureKeyValueStore();
    final store = SecureProviderCredentialStore(keyValueStore);

    await store.write(ProviderType.openai, 'openai-test-key');
    await store.write(ProviderType.qwen, 'qwen-test-key');

    expect(await store.read(ProviderType.openai), 'openai-test-key');
    expect(await store.read(ProviderType.qwen), 'qwen-test-key');
    expect(
      keyValueStore.values.keys,
      contains('aitrans.provider.openai.apiKey'),
    );
    expect(keyValueStore.values.keys, contains('aitrans.provider.qwen.apiKey'));
  });

  test('empty credential deletes only the selected provider entry', () async {
    final keyValueStore = _MemorySecureKeyValueStore();
    final store = SecureProviderCredentialStore(keyValueStore);
    await store.write(ProviderType.openai, 'openai-test-key');
    await store.write(ProviderType.qwen, 'qwen-test-key');

    await store.write(ProviderType.openai, '  ');

    expect(await store.read(ProviderType.openai), isNull);
    expect(await store.read(ProviderType.qwen), 'qwen-test-key');
  });

  test('does not swallow secure storage failures', () async {
    final store = SecureProviderCredentialStore(
      _MemorySecureKeyValueStore(failWrites: true),
    );

    await expectLater(
      store.write(ProviderType.qwen, 'qwen-test-key'),
      throwsA(isA<StateError>()),
    );
  });
}

class _MemorySecureKeyValueStore implements SecureKeyValueStore {
  _MemorySecureKeyValueStore({this.failWrites = false});

  final bool failWrites;
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async {
    if (failWrites) throw StateError('synthetic secure storage failure');
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrites) throw StateError('synthetic secure storage failure');
    values[key] = value;
  }
}
