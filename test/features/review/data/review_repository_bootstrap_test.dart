import 'package:aitrans/features/review/data/review_key_store.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/data/review_repository_bootstrap.dart';
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  test('an empty store provisions and verifies its independent key', () async {
    final keys = BootstrapReviewKeyStore();

    final repository = await ReviewRepositoryBootstrap.open(
      historyStore: BootstrapCiphertextStore(),
      contentStore: BootstrapCiphertextStore(),
      keyStore: keys,
    );

    expect(repository.state, ReviewRepositoryState.ready);
    expect(keys.createCount, 1);
    expect(keys.loadCount, 2);
  });

  test(
    'existing ciphertext with a missing key never creates a replacement',
    () async {
      final keys = BootstrapReviewKeyStore();

      await expectLater(
        () => ReviewRepositoryBootstrap.open(
          historyStore: BootstrapCiphertextStore({
            'opaque': const {'v': 1},
          }),
          contentStore: BootstrapCiphertextStore(),
          keyStore: keys,
        ),
        throwsA(isA<ReviewRepositoryUnavailableException>()),
      );

      expect(keys.createCount, 0);
    },
  );
}

class BootstrapReviewKeyStore implements ReviewKeyStore {
  SecretKey? key;
  int loadCount = 0;
  int createCount = 0;

  @override
  Future<SecretKey?> loadExisting() async {
    loadCount += 1;
    return key;
  }

  @override
  Future<SecretKey> create() async {
    createCount += 1;
    key = SecretKey(List<int>.filled(32, 21));
    return key!;
  }

  @override
  Future<void> delete() async => key = null;
}

class BootstrapCiphertextStore implements ReviewCiphertextStore {
  BootstrapCiphertextStore([Map<String, Object>? values])
    : _values = values ?? <String, Object>{};

  final Map<String, Object> _values;

  @override
  bool get isEmpty => _values.isEmpty;

  @override
  Iterable<String> get keys => _values.keys;

  @override
  Object? read(String key) => _values[key];

  @override
  Future<void> write(String key, Object value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> clear() async => _values.clear();
}
