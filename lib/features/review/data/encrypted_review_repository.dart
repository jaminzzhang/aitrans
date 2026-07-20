import 'dart:async';

import 'package:cryptography/cryptography.dart';

import '../domain/review_identity.dart';
import '../domain/review_feedback.dart';
import '../domain/review_scheduler.dart';
import '../models/review_entry.dart';
import 'review_key_store.dart';
import 'review_repository.dart';
import 'review_store_codec.dart';

class EncryptedReviewRepository implements ReviewRepository {
  EncryptedReviewRepository({
    required ReviewCiphertextStore historyStore,
    required ReviewCiphertextStore contentStore,
    required ReviewKeyStore keyStore,
    ReviewStoreCodec? codec,
    int derivedCacheLimitBytes = 128 * 1024 * 1024,
  }) : _historyStore = historyStore,
       _contentStore = contentStore,
       _keyStore = keyStore,
       _codec = codec ?? ReviewStoreCodec(),
       _derivedCacheLimitBytes = derivedCacheLimitBytes {
    if (derivedCacheLimitBytes < 0) {
      throw ArgumentError.value(
        derivedCacheLimitBytes,
        'derivedCacheLimitBytes',
      );
    }
  }

  final ReviewCiphertextStore _historyStore;
  final ReviewCiphertextStore _contentStore;
  final ReviewKeyStore _keyStore;
  final ReviewStoreCodec _codec;
  final int _derivedCacheLimitBytes;

  Future<void> _operationTail = Future<void>.value();
  SecretKey? _key;
  ReviewRepositoryState _state = ReviewRepositoryState.ready;

  @override
  ReviewRepositoryState get state => _state;

  @override
  Future<ReviewEntry?> find(ReviewIdentity identity) => _serialize(() async {
    _ensureAvailable();
    final storageKey = _codec.entryStorageKey(identity);
    final raw = _read(_historyStore, storageKey);
    if (raw == null) {
      if (!_historyStore.isEmpty || !_contentStore.isEmpty) {
        await _keyForExistingData();
      }
      return null;
    }
    final key = await _keyForExistingData();
    return _decryptAsync(raw: raw, storageKey: storageKey, key: key);
  });

  @override
  Future<List<ReviewEntry>> all() => _serialize(() async {
    _ensureAvailable();
    if (_historyStore.isEmpty) {
      return <ReviewEntry>[];
    }
    final key = await _keyForExistingData();
    final entries = <ReviewEntry>[];
    for (final storageKey in _historyStore.keys.where(
      (key) => key.startsWith('entry:'),
    )) {
      final raw = _read(_historyStore, storageKey);
      if (raw == null) {
        continue;
      }
      entries.add(
        await _decryptAsync(raw: raw, storageKey: storageKey, key: key),
      );
    }
    return List<ReviewEntry>.unmodifiable(entries);
  });

  @override
  Future<ReviewEntry> recordTranslation({
    required ReviewIdentity identity,
    required String originalAlias,
    required DateTime translatedAt,
    required ReviewEntryContent content,
  }) => _serialize(() async {
    _ensureAvailable();
    final storageKey = _codec.entryStorageKey(identity);
    final raw = _read(_historyStore, storageKey);
    final key = await _keyForWrite();
    final existing = raw == null
        ? null
        : await _decryptAsync(raw: raw, storageKey: storageKey, key: key);
    final generation = existing == null
        ? await _allocateGeneration(key)
        : existing.generation;
    final updated = existing == null
        ? ReviewEntry.firstTranslation(
            identity: identity,
            originalAlias: originalAlias,
            translatedAt: translatedAt,
            content: content,
            generation: generation,
          )
        : existing.recordTranslation(
            originalAlias: originalAlias,
            translatedAt: translatedAt,
            content: content,
          );
    final envelope = await _codec.encryptEntry(entry: updated, key: key);
    await _write(_historyStore, storageKey, envelope);
    return updated;
  });

  @override
  Future<ReviewEntry?> applyFeedback({
    required ReviewIdentity identity,
    required ReviewFeedbackEvent event,
    required ReviewScheduler scheduler,
  }) => _serialize(() async {
    _ensureAvailable();
    final storageKey = _codec.entryStorageKey(identity);
    final raw = _read(_historyStore, storageKey);
    if (raw == null) return null;
    final key = await _keyForExistingData();
    final existing = await _decryptAsync(
      raw: raw,
      storageKey: storageKey,
      key: key,
    );
    final updatedState = scheduler.applyFeedback(
      state: ReviewScheduleState(
        entry: existing,
        appliedFeedbackEventIds: existing.appliedFeedbackEventIds,
      ),
      event: event,
    );
    if (identical(updatedState.entry, existing)) return existing;
    final envelope = await _codec.encryptEntry(
      entry: updatedState.entry,
      key: key,
    );
    await _write(_historyStore, storageKey, envelope);
    return updatedState.entry;
  });

  @override
  Future<bool> putDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required String mediaType,
    required List<int> bytes,
    required int expectedGeneration,
    required DateTime accessedAt,
  }) => _serialize(() async {
    _ensureAvailable();
    final normalizedContentId = contentId.trim();
    final normalizedMediaType = mediaType.trim();
    if (normalizedContentId.isEmpty || normalizedMediaType.isEmpty) {
      throw ArgumentError('Derived content requires an id and media type.');
    }
    final entryStorageKey = _codec.entryStorageKey(identity);
    final entryRaw = _read(_historyStore, entryStorageKey);
    if (entryRaw == null) {
      return false;
    }
    final key = await _keyForExistingData();
    final entry = await _decryptAsync(
      raw: entryRaw,
      storageKey: entryStorageKey,
      key: key,
    );
    if (entry.generation != expectedGeneration) {
      return false;
    }

    final derivedContent = ReviewDerivedContent(
      identity: identity,
      contentId: normalizedContentId,
      mediaType: normalizedMediaType,
      bytes: bytes,
      generation: expectedGeneration,
      lastAccessedAt: accessedAt,
    );
    final contentStorageKey = _codec.contentStorageKey(
      identity,
      normalizedContentId,
    );
    final envelope = await _codec.encryptDerivedContent(
      content: derivedContent,
      key: key,
    );
    await _write(_contentStore, contentStorageKey, envelope);
    await _evictDerivedContent(key);
    return _read(_contentStore, contentStorageKey) != null;
  });

  @override
  Future<ReviewDerivedContent?> findDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required DateTime accessedAt,
  }) => _serialize(() async {
    _ensureAvailable();
    final normalizedContentId = contentId.trim();
    if (normalizedContentId.isEmpty) {
      throw ArgumentError.value(contentId, 'contentId');
    }
    final contentStorageKey = _codec.contentStorageKey(
      identity,
      normalizedContentId,
    );
    final contentRaw = _read(_contentStore, contentStorageKey);
    if (contentRaw == null) {
      if (!_historyStore.isEmpty || !_contentStore.isEmpty) {
        await _keyForExistingData();
      }
      return null;
    }
    final entryStorageKey = _codec.entryStorageKey(identity);
    final entryRaw = _read(_historyStore, entryStorageKey);
    if (entryRaw == null) {
      await _delete(_contentStore, contentStorageKey);
      return null;
    }
    final key = await _keyForExistingData();
    final entry = await _decryptAsync(
      raw: entryRaw,
      storageKey: entryStorageKey,
      key: key,
    );
    final content = await _decryptDerivedContentAsync(
      raw: contentRaw,
      storageKey: contentStorageKey,
      key: key,
    );
    if (content.identity != identity ||
        content.contentId != normalizedContentId ||
        content.generation != entry.generation) {
      await _delete(_contentStore, contentStorageKey);
      return null;
    }
    final lastAccessedAt = accessedAt.isAfter(content.lastAccessedAt)
        ? accessedAt
        : content.lastAccessedAt;
    final updated = ReviewDerivedContent(
      identity: content.identity,
      contentId: content.contentId,
      mediaType: content.mediaType,
      bytes: content.bytes,
      generation: content.generation,
      lastAccessedAt: lastAccessedAt,
    );
    final envelope = await _codec.encryptDerivedContent(
      content: updated,
      key: key,
    );
    await _write(_contentStore, contentStorageKey, envelope);
    return updated;
  });

  @override
  Future<void> delete(ReviewIdentity identity) => _serialize(() async {
    _ensureAvailable();
    final storageKey = _codec.entryStorageKey(identity);
    final contentPrefix = _codec.contentStoragePrefix(identity);
    for (final contentKey in _contentStore.keys.where(
      (key) => key.startsWith(contentPrefix),
    )) {
      await _delete(_contentStore, contentKey);
    }
    await _delete(_historyStore, storageKey);
  });

  @override
  Future<void> clearAndReset() => _serialize(() async {
    try {
      await _contentStore.clear();
      await _historyStore.clear();
      await _keyStore.delete();
      _key = null;
      _state = ReviewRepositoryState.ready;
    } catch (_) {
      _becomeUnavailable();
    }
  });

  Object? _read(ReviewCiphertextStore store, String storageKey) {
    try {
      return store.read(storageKey);
    } catch (_) {
      _becomeUnavailable();
    }
  }

  Future<void> _write(
    ReviewCiphertextStore store,
    String storageKey,
    Object value,
  ) async {
    try {
      await store.write(storageKey, value);
    } catch (_) {
      _becomeUnavailable();
    }
  }

  Future<void> _delete(ReviewCiphertextStore store, String storageKey) async {
    try {
      await store.delete(storageKey);
    } catch (_) {
      _becomeUnavailable();
    }
  }

  Future<int> _allocateGeneration(SecretKey key) async {
    final raw = _read(_historyStore, ReviewStoreCodec.generationStorageKey);
    var generation = 0;
    if (raw != null) {
      try {
        generation = await _codec.decryptNextGeneration(
          envelope: _envelope(raw),
          key: key,
        );
      } on ReviewStoreCorruptedException {
        _becomeUnavailable();
      } catch (_) {
        _becomeUnavailable();
      }
    }
    final nextEnvelope = await _codec.encryptNextGeneration(
      nextGeneration: generation + 1,
      key: key,
    );
    await _write(
      _historyStore,
      ReviewStoreCodec.generationStorageKey,
      nextEnvelope,
    );
    return generation;
  }

  Future<void> _evictDerivedContent(SecretKey key) async {
    final contents = <({String storageKey, ReviewDerivedContent content})>[];
    var totalBytes = 0;
    for (final storageKey in _contentStore.keys.where(
      (key) => key.startsWith('content:'),
    )) {
      final raw = _read(_contentStore, storageKey);
      if (raw == null) {
        continue;
      }
      final content = await _decryptDerivedContentAsync(
        raw: raw,
        storageKey: storageKey,
        key: key,
      );
      contents.add((storageKey: storageKey, content: content));
      totalBytes += content.byteLength;
    }
    contents.sort((left, right) {
      final byAccess = left.content.lastAccessedAt.compareTo(
        right.content.lastAccessedAt,
      );
      return byAccess != 0
          ? byAccess
          : left.storageKey.compareTo(right.storageKey);
    });
    for (final candidate in contents) {
      if (totalBytes <= _derivedCacheLimitBytes) {
        break;
      }
      await _delete(_contentStore, candidate.storageKey);
      totalBytes -= candidate.content.byteLength;
    }
  }

  Future<ReviewEntry> _decryptAsync({
    required Object raw,
    required String storageKey,
    required SecretKey key,
  }) async {
    if (raw is! Map) {
      _becomeUnavailable();
    }
    try {
      return await _codec.decryptEntryAtStorageKey(
        envelope: _envelope(raw),
        storageKey: storageKey,
        key: key,
      );
    } on ReviewStoreCorruptedException {
      _becomeUnavailable();
    } catch (_) {
      _becomeUnavailable();
    }
  }

  Future<ReviewDerivedContent> _decryptDerivedContentAsync({
    required Object raw,
    required String storageKey,
    required SecretKey key,
  }) async {
    try {
      return await _codec.decryptDerivedContentAtStorageKey(
        envelope: _envelope(raw),
        storageKey: storageKey,
        key: key,
      );
    } on ReviewStoreCorruptedException {
      _becomeUnavailable();
    } catch (_) {
      _becomeUnavailable();
    }
  }

  Map<Object?, Object?> _envelope(Object raw) {
    if (raw is! Map) {
      _becomeUnavailable();
    }
    return Map<Object?, Object?>.from(raw);
  }

  Future<SecretKey> _keyForExistingData() async {
    final cached = _key;
    if (cached != null) {
      return cached;
    }
    try {
      final existing = await _keyStore.loadExisting();
      if (existing == null) {
        _becomeUnavailable();
      }
      return _key = existing;
    } on ReviewKeyUnavailableException {
      _becomeUnavailable();
    } catch (_) {
      _becomeUnavailable();
    }
  }

  Future<SecretKey> _keyForWrite() async {
    final cached = _key;
    if (cached != null) {
      return cached;
    }
    try {
      final existing = await _keyStore.loadExisting();
      if (existing != null) {
        return _key = existing;
      }
      if (!_historyStore.isEmpty || !_contentStore.isEmpty) {
        _becomeUnavailable();
      }
      return _key = await _keyStore.create();
    } on ReviewKeyUnavailableException {
      _becomeUnavailable();
    } catch (_) {
      _becomeUnavailable();
    }
  }

  void _ensureAvailable() {
    if (_state == ReviewRepositoryState.unavailable) {
      throw const ReviewRepositoryUnavailableException();
    }
  }

  Never _becomeUnavailable() {
    _state = ReviewRepositoryState.unavailable;
    throw const ReviewRepositoryUnavailableException();
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final result = _operationTail.then((_) => operation());
    _operationTail = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }
}
