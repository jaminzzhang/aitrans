import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ReviewKeyUnavailableException implements Exception {
  const ReviewKeyUnavailableException();

  @override
  String toString() => 'ReviewKeyUnavailableException';
}

abstract interface class ReviewKeyStore {
  Future<SecretKey?> loadExisting();

  Future<SecretKey> create();

  Future<void> delete();
}

abstract interface class ReviewKeyValueStore {
  Future<String?> read();

  Future<void> write(String value);

  Future<void> delete();
}

class FlutterReviewKeyValueStore implements ReviewKeyValueStore {
  static const String _reviewKeyName = 'review_master_key_v1';
  static const String _accountName = 'com.aitrans.aitrans.review-key-v1';

  static const AndroidOptions androidOptions = AndroidOptions(
    resetOnError: false,
    migrateOnAlgorithmChange: true,
    migrateWithBackup: true,
    storageNamespace: 'aitrans_review_keys_v1',
  );
  static const IOSOptions iosOptions = IOSOptions(
    accountName: _accountName,
    accessibility: KeychainAccessibility.first_unlock_this_device,
    synchronizable: false,
  );
  static const MacOsOptions macosOptions = MacOsOptions(
    accountName: _accountName,
    accessibility: KeychainAccessibility.unlocked_this_device,
    synchronizable: false,
    usesDataProtectionKeychain: false,
  );

  FlutterReviewKeyValueStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: androidOptions,
            iOptions: iosOptions,
            mOptions: macosOptions,
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _reviewKeyName);

  @override
  Future<void> write(String value) =>
      _storage.write(key: _reviewKeyName, value: value);

  @override
  Future<void> delete() => _storage.delete(key: _reviewKeyName);
}

typedef ReviewKeyBytesFactory = List<int> Function();

class PlatformReviewKeyStore implements ReviewKeyStore {
  PlatformReviewKeyStore({
    ReviewKeyValueStore? values,
    ReviewKeyBytesFactory? keyBytesFactory,
  }) : _values = values ?? FlutterReviewKeyValueStore(),
       _keyBytesFactory = keyBytesFactory ?? _secureKeyBytes;

  final ReviewKeyValueStore _values;
  final ReviewKeyBytesFactory _keyBytesFactory;
  Future<void> _operationTail = Future<void>.value();

  @override
  Future<SecretKey?> loadExisting() => _serialize(() async {
    final keyBytes = await _readExistingBytes();
    return keyBytes == null ? null : SecretKey(keyBytes);
  });

  @override
  Future<SecretKey> create() => _serialize(() async {
    final existing = await _readExistingBytes();
    if (existing != null) {
      return SecretKey(existing);
    }

    final generated = _keyBytesFactory();
    if (!_isValidKey(generated)) {
      throw const ReviewKeyUnavailableException();
    }
    try {
      await _values.write(base64Encode(generated));
      final persisted = await _readExistingBytes();
      if (persisted == null || !_constantTimeEquals(generated, persisted)) {
        throw const ReviewKeyUnavailableException();
      }
      return SecretKey(persisted);
    } on ReviewKeyUnavailableException {
      rethrow;
    } catch (_) {
      throw const ReviewKeyUnavailableException();
    }
  });

  @override
  Future<void> delete() => _serialize(() async {
    try {
      await _values.delete();
    } catch (_) {
      throw const ReviewKeyUnavailableException();
    }
  });

  Future<List<int>?> _readExistingBytes() async {
    try {
      final encoded = await _values.read();
      if (encoded == null) {
        return null;
      }
      final decoded = base64Decode(encoded);
      if (!_isValidKey(decoded)) {
        throw const ReviewKeyUnavailableException();
      }
      return decoded;
    } on ReviewKeyUnavailableException {
      rethrow;
    } catch (_) {
      throw const ReviewKeyUnavailableException();
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operationTail.then((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  static bool _isValidKey(List<int> bytes) =>
      bytes.length == 32 && bytes.every((value) => value >= 0 && value <= 255);

  static bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  static List<int> _secureKeyBytes() {
    final random = Random.secure();
    return List<int>.generate(32, (_) => random.nextInt(256));
  }
}
