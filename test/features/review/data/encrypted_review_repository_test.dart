import 'dart:convert';

import 'package:aitrans/features/review/data/encrypted_review_repository.dart';
import 'package:aitrans/features/review/data/review_key_store.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/data/review_store_codec.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  final identity = ReviewIdentity.create(
    correctedTerm: 'private-fox-term',
    actualSourceLanguage: TranslationSourceLanguage.en,
    targetLanguage: TranslationSourceLanguage.zh,
  );
  final firstContent = ReviewEntryContent(
    sourceText: 'private-fox-term',
    translationText: '私密狐狸译文',
    primaryMeaning: '私密狐狸词义',
    secondaryMeanings: const [],
  );

  test(
    'concurrent translations merge without plaintext or lost counts',
    () async {
      final history = MemoryReviewCiphertextStore();
      final keys = MemoryReviewKeyStore();
      final repository = EncryptedReviewRepository(
        historyStore: history,
        contentStore: MemoryReviewCiphertextStore(),
        keyStore: keys,
      );

      final entries = await Future.wait([
        repository.recordTranslation(
          identity: identity,
          originalAlias: 'private-fox-alias-a',
          translatedAt: DateTime.utc(2026, 7, 19, 8),
          content: firstContent,
        ),
        repository.recordTranslation(
          identity: identity,
          originalAlias: 'private-fox-alias-b',
          translatedAt: DateTime.utc(2026, 7, 19, 9),
          content: ReviewEntryContent(
            sourceText: 'private-fox-term',
            translationText: '私密狐狸新译文',
            primaryMeaning: '私密狐狸新词义',
            secondaryMeanings: const [],
          ),
        ),
        repository.recordTranslation(
          identity: identity,
          originalAlias: 'private-fox-alias-c',
          translatedAt: DateTime.utc(2026, 7, 19, 10),
          content: ReviewEntryContent(
            sourceText: 'private-fox-term',
            translationText: '私密狐狸最新译文',
            primaryMeaning: '私密狐狸最新词义',
            secondaryMeanings: const [],
          ),
        ),
      ]);

      final stored = await repository.find(identity);
      final rawStorage = jsonEncode(history.values);
      expect(entries.map((entry) => entry.translationCount), [1, 2, 3]);
      expect(stored!.translationCount, 3);
      expect(stored.aliases, {
        'private-fox-alias-a',
        'private-fox-alias-b',
        'private-fox-alias-c',
      });
      expect(stored.latestContent.translationText, '私密狐狸最新译文');
      expect(rawStorage, isNot(contains('private-fox')));
      expect(rawStorage, isNot(contains('私密狐狸')));
      expect(keys.createCount, 1);
      expect(repository.state, ReviewRepositoryState.ready);
    },
  );

  test(
    'feedback is atomically scheduled and idempotent after reopen',
    () async {
      final history = MemoryReviewCiphertextStore();
      final keys = MemoryReviewKeyStore();
      final repository = EncryptedReviewRepository(
        historyStore: history,
        contentStore: MemoryReviewCiphertextStore(),
        keyStore: keys,
      );
      await repository.recordTranslation(
        identity: identity,
        originalAlias: 'private-fox-alias',
        translatedAt: DateTime.utc(2026, 7, 19, 8),
        content: firstContent,
      );
      final scheduler = ReviewScheduler(
        now: () => DateTime.utc(2026, 7, 20, 8),
      );
      final event = ReviewFeedbackEvent(
        id: 'feedback-private-atomic-1',
        feedback: ReviewFeedback.forgotten,
      );

      await Future.wait([
        repository.applyFeedback(
          identity: identity,
          event: event,
          scheduler: scheduler,
        ),
        repository.applyFeedback(
          identity: identity,
          event: event,
          scheduler: scheduler,
        ),
      ]);
      final reopened = EncryptedReviewRepository(
        historyStore: history,
        contentStore: MemoryReviewCiphertextStore(),
        keyStore: keys,
      );
      final duplicate = await reopened.applyFeedback(
        identity: identity,
        event: event,
        scheduler: scheduler,
      );

      expect(duplicate, isNotNull);
      expect(duplicate!.forgetCount, 1);
      expect(duplicate.consecutiveRememberedCount, 0);
      expect(duplicate.nextReviewAt, DateTime.utc(2026, 7, 20, 8, 10));
      expect(duplicate.appliedFeedbackEventIds, {'feedback-private-atomic-1'});
      expect(jsonEncode(history.values), isNot(contains('feedback-private')));
    },
  );

  test(
    'ciphertext with a missing key becomes explicitly unavailable',
    () async {
      final actualKey = SecretKey(List<int>.filled(32, 4));
      final codec = ReviewStoreCodec();
      final entry = ReviewEntry.firstTranslation(
        identity: identity,
        originalAlias: 'private-fox-alias',
        translatedAt: DateTime.utc(2026, 7, 19, 8),
        content: firstContent,
      );
      final history = MemoryReviewCiphertextStore(
        values: {
          codec.entryStorageKey(identity): await codec.encryptEntry(
            entry: entry,
            key: actualKey,
          ),
        },
      );
      final keys = MemoryReviewKeyStore.missing();
      final repository = EncryptedReviewRepository(
        historyStore: history,
        contentStore: MemoryReviewCiphertextStore(),
        keyStore: keys,
      );

      await expectLater(
        () => repository.find(identity),
        throwsA(isA<ReviewRepositoryUnavailableException>()),
      );

      expect(repository.state, ReviewRepositoryState.unavailable);
      expect(keys.createCount, 0);
      expect(history.writeCount, 0);
    },
  );

  test('a miss cannot hide that another ciphertext has lost its key', () async {
    final actualKey = SecretKey(List<int>.filled(32, 4));
    final codec = ReviewStoreCodec();
    final entry = ReviewEntry.firstTranslation(
      identity: identity,
      originalAlias: 'private-fox-alias',
      translatedAt: DateTime.utc(2026, 7, 19, 8),
      content: firstContent,
    );
    final history = MemoryReviewCiphertextStore(
      values: {
        codec.entryStorageKey(identity): await codec.encryptEntry(
          entry: entry,
          key: actualKey,
        ),
      },
    );
    final repository = EncryptedReviewRepository(
      historyStore: history,
      contentStore: MemoryReviewCiphertextStore(),
      keyStore: MemoryReviewKeyStore.missing(),
    );
    final absentIdentity = ReviewIdentity.create(
      correctedTerm: 'absent-private-fox',
      actualSourceLanguage: TranslationSourceLanguage.en,
      targetLanguage: TranslationSourceLanguage.zh,
    );

    await expectLater(
      () => repository.find(absentIdentity),
      throwsA(isA<ReviewRepositoryUnavailableException>()),
    );
    expect(repository.state, ReviewRepositoryState.unavailable);
  });

  test('a failed atomic write leaves the previous record intact', () async {
    final history = MemoryReviewCiphertextStore();
    final keys = MemoryReviewKeyStore();
    final repository = EncryptedReviewRepository(
      historyStore: history,
      contentStore: MemoryReviewCiphertextStore(),
      keyStore: keys,
    );
    await repository.recordTranslation(
      identity: identity,
      originalAlias: 'private-fox-alias-a',
      translatedAt: DateTime.utc(2026, 7, 19, 8),
      content: firstContent,
    );
    history.failNextWrite = true;

    await expectLater(
      () => repository.recordTranslation(
        identity: identity,
        originalAlias: 'private-fox-alias-b',
        translatedAt: DateTime.utc(2026, 7, 19, 9),
        content: firstContent,
      ),
      throwsA(isA<ReviewRepositoryUnavailableException>()),
    );

    final reopened = EncryptedReviewRepository(
      historyStore: history,
      contentStore: MemoryReviewCiphertextStore(),
      keyStore: keys,
    );
    final stored = await reopened.find(identity);
    expect(stored!.translationCount, 1);
    expect(stored.aliases, {'private-fox-alias-a'});
  });

  test(
    'tampered history becomes unavailable instead of partial data',
    () async {
      final history = MemoryReviewCiphertextStore();
      final repository = EncryptedReviewRepository(
        historyStore: history,
        contentStore: MemoryReviewCiphertextStore(),
        keyStore: MemoryReviewKeyStore(),
      );
      await repository.recordTranslation(
        identity: identity,
        originalAlias: 'private-fox-alias',
        translatedAt: DateTime.utc(2026, 7, 19, 8),
        content: firstContent,
      );
      final storageKey = history.values.keys
          .where((key) => key.startsWith('entry:'))
          .single;
      final envelope = Map<String, Object>.from(
        history.values[storageKey]! as Map,
      );
      final cipherText = base64Decode(envelope['cipherText']! as String);
      cipherText[0] ^= 0x01;
      history.values[storageKey] = {
        ...envelope,
        'cipherText': base64Encode(cipherText),
      };

      await expectLater(
        () => repository.find(identity),
        throwsA(isA<ReviewRepositoryUnavailableException>()),
      );
      expect(repository.state, ReviewRepositoryState.unavailable);
    },
  );

  test('delete removes history and every derived content record', () async {
    final history = MemoryReviewCiphertextStore();
    final content = MemoryReviewCiphertextStore();
    final repository = EncryptedReviewRepository(
      historyStore: history,
      contentStore: content,
      keyStore: MemoryReviewKeyStore(),
    );
    final entry = await repository.recordTranslation(
      identity: identity,
      originalAlias: 'private-fox-alias',
      translatedAt: DateTime.utc(2026, 7, 19, 8),
      content: firstContent,
    );
    expect(
      await repository.putDerivedContent(
        identity: identity,
        contentId: 'private-image-contract',
        mediaType: 'image/png',
        bytes: utf8.encode('private-derived-image'),
        expectedGeneration: entry.generation,
        accessedAt: DateTime.utc(2026, 7, 19, 9),
      ),
      isTrue,
    );

    await repository.delete(identity);

    expect(await repository.find(identity), isNull);
    expect(
      await repository.findDerivedContent(
        identity: identity,
        contentId: 'private-image-contract',
        accessedAt: DateTime.utc(2026, 7, 19, 10),
      ),
      isNull,
    );
    expect(content.values, isEmpty);
    expect(
      history.values.keys.where((key) => key.startsWith('entry:')),
      isEmpty,
    );
  });

  test('a late derived write cannot attach to a recreated entry', () async {
    final content = MemoryReviewCiphertextStore();
    final repository = EncryptedReviewRepository(
      historyStore: MemoryReviewCiphertextStore(),
      contentStore: content,
      keyStore: MemoryReviewKeyStore(),
    );
    final deletedEntry = await repository.recordTranslation(
      identity: identity,
      originalAlias: 'private-fox-alias',
      translatedAt: DateTime.utc(2026, 7, 19, 8),
      content: firstContent,
    );
    await repository.delete(identity);
    final recreatedEntry = await repository.recordTranslation(
      identity: identity,
      originalAlias: 'private-fox-alias',
      translatedAt: DateTime.utc(2026, 7, 19, 9),
      content: firstContent,
    );

    final accepted = await repository.putDerivedContent(
      identity: identity,
      contentId: 'late-private-content',
      mediaType: 'image/png',
      bytes: utf8.encode('late-private-bytes'),
      expectedGeneration: deletedEntry.generation,
      accessedAt: DateTime.utc(2026, 7, 19, 10),
    );

    expect(recreatedEntry.generation, greaterThan(deletedEntry.generation));
    expect(accepted, isFalse);
    expect(content.values, isEmpty);
  });

  test(
    'derived cache evicts least recently used content at its byte cap',
    () async {
      final content = MemoryReviewCiphertextStore();
      final repository = EncryptedReviewRepository(
        historyStore: MemoryReviewCiphertextStore(),
        contentStore: content,
        keyStore: MemoryReviewKeyStore(),
        derivedCacheLimitBytes: 10,
      );
      final entry = await repository.recordTranslation(
        identity: identity,
        originalAlias: 'private-fox-alias',
        translatedAt: DateTime.utc(2026, 7, 19, 8),
        content: firstContent,
      );
      await repository.putDerivedContent(
        identity: identity,
        contentId: 'private-content-a',
        mediaType: 'image/png',
        bytes: const [1, 2, 3, 4, 5, 6],
        expectedGeneration: entry.generation,
        accessedAt: DateTime.utc(2026, 7, 19, 9),
      );
      await repository.putDerivedContent(
        identity: identity,
        contentId: 'private-content-b',
        mediaType: 'video/mp4',
        bytes: const [7, 8, 9, 10, 11, 12],
        expectedGeneration: entry.generation,
        accessedAt: DateTime.utc(2026, 7, 19, 10),
      );

      expect(
        await repository.findDerivedContent(
          identity: identity,
          contentId: 'private-content-a',
          accessedAt: DateTime.utc(2026, 7, 19, 11),
        ),
        isNull,
      );
      final retained = await repository.findDerivedContent(
        identity: identity,
        contentId: 'private-content-b',
        accessedAt: DateTime.utc(2026, 7, 19, 11),
      );
      expect(retained!.mediaType, 'video/mp4');
      expect(retained.bytes, [7, 8, 9, 10, 11, 12]);
      expect(jsonEncode(content.values), isNot(contains('private-content')));
    },
  );

  test(
    'safe clear removes ciphertext before deleting the review key',
    () async {
      final operations = <String>[];
      final history = MemoryReviewCiphertextStore(
        onClear: () => operations.add('history'),
      );
      final content = MemoryReviewCiphertextStore(
        onClear: () => operations.add('content'),
      );
      final keys = MemoryReviewKeyStore(onDelete: () => operations.add('key'));
      final repository = EncryptedReviewRepository(
        historyStore: history,
        contentStore: content,
        keyStore: keys,
      );
      await repository.recordTranslation(
        identity: identity,
        originalAlias: 'private-fox-alias',
        translatedAt: DateTime.utc(2026, 7, 19, 8),
        content: firstContent,
      );

      await repository.clearAndReset();

      expect(operations, ['content', 'history', 'key']);
      expect(repository.state, ReviewRepositoryState.ready);
      expect(history.values, isEmpty);
      expect(content.values, isEmpty);
    },
  );
}

class MemoryReviewKeyStore implements ReviewKeyStore {
  MemoryReviewKeyStore({this.key, this.onDelete});

  MemoryReviewKeyStore.missing() : key = null, onDelete = null;

  SecretKey? key;
  final void Function()? onDelete;
  int createCount = 0;
  int deleteCount = 0;

  @override
  Future<SecretKey?> loadExisting() async => key;

  @override
  Future<SecretKey> create() async {
    createCount += 1;
    return key ??= SecretKey(List<int>.filled(32, 9));
  }

  @override
  Future<void> delete() async {
    deleteCount += 1;
    onDelete?.call();
    key = null;
  }
}

class MemoryReviewCiphertextStore implements ReviewCiphertextStore {
  MemoryReviewCiphertextStore({Map<String, Object>? values, this.onClear})
    : values = values ?? <String, Object>{};

  final Map<String, Object> values;
  final void Function()? onClear;
  bool failNextWrite = false;
  int writeCount = 0;

  @override
  bool get isEmpty => values.isEmpty;

  @override
  Iterable<String> get keys => List<String>.of(values.keys);

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> write(String key, Object value) async {
    writeCount += 1;
    if (failNextWrite) {
      failNextWrite = false;
      throw StateError('disk full');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    onClear?.call();
    values.clear();
  }
}
