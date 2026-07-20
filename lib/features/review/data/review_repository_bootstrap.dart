import 'package:cryptography/cryptography.dart';

import 'encrypted_review_repository.dart';
import 'review_key_store.dart';
import 'review_repository.dart';
import 'review_store_codec.dart';

abstract final class ReviewRepositoryBootstrap {
  static Future<ReviewRepository> open({
    required ReviewCiphertextStore historyStore,
    required ReviewCiphertextStore contentStore,
    required ReviewKeyStore keyStore,
    ReviewStoreCodec? codec,
    int derivedCacheLimitBytes = 128 * 1024 * 1024,
  }) async {
    try {
      final existingKey = await keyStore.loadExisting();
      if (existingKey == null) {
        if (!historyStore.isEmpty || !contentStore.isEmpty) {
          throw const ReviewRepositoryUnavailableException();
        }
        final createdKey = await keyStore.create();
        final persistedKey = await keyStore.loadExisting();
        if (persistedKey == null || !await _sameKey(createdKey, persistedKey)) {
          throw const ReviewRepositoryUnavailableException();
        }
      }
      return EncryptedReviewRepository(
        historyStore: historyStore,
        contentStore: contentStore,
        keyStore: keyStore,
        codec: codec,
        derivedCacheLimitBytes: derivedCacheLimitBytes,
      );
    } on ReviewRepositoryUnavailableException {
      rethrow;
    } on ReviewKeyUnavailableException {
      throw const ReviewRepositoryUnavailableException();
    } catch (_) {
      throw const ReviewRepositoryUnavailableException();
    }
  }

  static Future<bool> _sameKey(SecretKey left, SecretKey right) async {
    final leftBytes = await left.extractBytes();
    final rightBytes = await right.extractBytes();
    if (leftBytes.length != rightBytes.length) {
      return false;
    }
    var difference = 0;
    for (var index = 0; index < leftBytes.length; index++) {
      difference |= leftBytes[index] ^ rightBytes[index];
    }
    return difference == 0;
  }
}
