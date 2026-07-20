import 'dart:convert';

import 'package:aitrans/features/review/data/review_key_store.dart';
import 'package:test/test.dart';

void main() {
  test('creates and persists one independent 256-bit review key', () async {
    final values = FakeReviewKeyValueStore();
    final keyStore = PlatformReviewKeyStore(
      values: values,
      keyBytesFactory: () => List<int>.generate(32, (index) => index + 1),
    );

    final created = await keyStore.create();
    final loaded = await keyStore.loadExisting();

    expect(await created.extractBytes(), List<int>.generate(32, (i) => i + 1));
    expect(await loaded!.extractBytes(), await created.extractBytes());
    expect(values.writeCount, 1);
    expect(base64Decode(values.value!), hasLength(32));
  });

  test(
    'concurrent creation persists one key and returns it to all callers',
    () async {
      final values = FakeReviewKeyValueStore(writeDelay: Duration.zero);
      var generatedCount = 0;
      final keyStore = PlatformReviewKeyStore(
        values: values,
        keyBytesFactory: () {
          generatedCount += 1;
          return List<int>.filled(32, generatedCount);
        },
      );

      final keys = await Future.wait([
        keyStore.create(),
        keyStore.create(),
        keyStore.create(),
      ]);

      expect(values.writeCount, 1);
      expect(generatedCount, 1);
      expect(
        await Future.wait(keys.map((key) => key.extractBytes())),
        everyElement(List<int>.filled(32, 1)),
      );
    },
  );

  test('a malformed stored key is unavailable and is never replaced', () async {
    final values = FakeReviewKeyValueStore(value: base64Encode([1, 2, 3]));
    final keyStore = PlatformReviewKeyStore(values: values);

    await expectLater(
      keyStore.create,
      throwsA(isA<ReviewKeyUnavailableException>()),
    );

    expect(values.writeCount, 0);
    expect(values.deleteCount, 0);
  });

  test(
    'a secure storage read failure is explicit and does not write',
    () async {
      final values = FakeReviewKeyValueStore(readError: StateError('locked'));
      final keyStore = PlatformReviewKeyStore(values: values);

      await expectLater(
        keyStore.loadExisting,
        throwsA(isA<ReviewKeyUnavailableException>()),
      );

      expect(values.writeCount, 0);
    },
  );

  test('deletes only the review key after an explicit reset', () async {
    final values = FakeReviewKeyValueStore(
      value: base64Encode(List.filled(32, 7)),
    );
    final keyStore = PlatformReviewKeyStore(values: values);

    await keyStore.delete();

    expect(values.deleteCount, 1);
    expect(values.value, isNull);
  });

  test(
    'platform options disable destructive recovery and device migration',
    () {
      final android = FlutterReviewKeyValueStore.androidOptions.toMap();
      final ios = FlutterReviewKeyValueStore.iosOptions.toMap();
      final macos = FlutterReviewKeyValueStore.macosOptions.toMap();

      expect(android['resetOnError'], 'false');
      expect(android['storageNamespace'], 'aitrans_review_keys_v1');
      expect(android['storageCipherAlgorithm'], 'AES_GCM_NoPadding');
      expect(ios['accessibility'], 'first_unlock_this_device');
      expect(ios['synchronizable'], 'false');
      expect(macos['accessibility'], 'unlocked_this_device');
      expect(macos['synchronizable'], 'false');
      expect(macos['usesDataProtectionKeychain'], 'false');
    },
  );
}

class FakeReviewKeyValueStore implements ReviewKeyValueStore {
  FakeReviewKeyValueStore({this.value, this.readError, this.writeDelay});

  String? value;
  final Object? readError;
  final Duration? writeDelay;
  int writeCount = 0;
  int deleteCount = 0;

  @override
  Future<String?> read() async {
    final error = readError;
    if (error != null) {
      throw error;
    }
    return value;
  }

  @override
  Future<void> write(String value) async {
    writeCount += 1;
    final delay = writeDelay;
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    this.value = value;
  }

  @override
  Future<void> delete() async {
    deleteCount += 1;
    value = null;
  }
}
