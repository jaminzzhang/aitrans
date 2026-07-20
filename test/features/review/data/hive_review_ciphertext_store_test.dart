import 'dart:convert';
import 'dart:io';

import 'package:aitrans/core/security/local_master_key_store.dart';
import 'package:aitrans/features/review/data/encrypted_review_repository.dart';
import 'package:aitrans/features/review/data/hive_review_ciphertext_store.dart';
import 'package:aitrans/features/review/data/review_key_store.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:hive/hive.dart';
import 'package:test/test.dart';

void main() {
  late Directory directory;
  late Box<dynamic> historyBox;
  late Box<dynamic> contentBox;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('aitrans-review-hive-');
    Hive.init(directory.path);
    historyBox = await Hive.openBox<dynamic>('review_history');
    contentBox = await Hive.openBox<dynamic>('review_content');
  });

  tearDown(() async {
    await historyBox.close();
    await contentBox.close();
    await directory.delete(recursive: true);
  });

  test(
    'real Hive files contain ciphertext only and reopen independently',
    () async {
      final keys = FixedReviewKeyStore();
      final identity = ReviewIdentity.create(
        correctedTerm: 'private-hive-term',
        actualSourceLanguage: TranslationSourceLanguage.en,
        targetLanguage: TranslationSourceLanguage.zh,
      );
      final repository = EncryptedReviewRepository(
        historyStore: HiveReviewCiphertextStore(historyBox),
        contentStore: HiveReviewCiphertextStore(contentBox),
        keyStore: keys,
      );
      final entry = await repository.recordTranslation(
        identity: identity,
        originalAlias: 'private-hive-alias',
        translatedAt: DateTime.utc(2026, 7, 19, 8),
        content: ReviewEntryContent(
          sourceText: 'private-hive-term',
          translationText: '私密蜂巢译文',
          primaryMeaning: '私密蜂巢词义',
          secondaryMeanings: const [],
        ),
      );
      await repository.putDerivedContent(
        identity: identity,
        contentId: 'private-hive-image',
        mediaType: 'image/png',
        bytes: utf8.encode('private-hive-derived-bytes'),
        expectedGeneration: entry.generation,
        accessedAt: DateTime.utc(2026, 7, 19, 9),
      );
      await historyBox.flush();
      await contentBox.flush();

      for (final box in [historyBox, contentBox]) {
        final rawMap = jsonEncode(box.toMap());
        final rawFile = await File(box.path!).readAsBytes();
        for (final secret in [
          'private-hive-term',
          'private-hive-alias',
          'private-hive-image',
          'private-hive-derived-bytes',
          '私密蜂巢',
        ]) {
          expect(rawMap, isNot(contains(secret)));
          expect(_containsBytes(rawFile, utf8.encode(secret)), isFalse);
        }
      }

      final reopened = EncryptedReviewRepository(
        historyStore: HiveReviewCiphertextStore(historyBox),
        contentStore: HiveReviewCiphertextStore(contentBox),
        keyStore: keys,
      );
      expect((await reopened.find(identity))!.translationCount, 1);
      expect(
        (await reopened.findDerivedContent(
          identity: identity,
          contentId: 'private-hive-image',
          accessedAt: DateTime.utc(2026, 7, 19, 10),
        ))!.bytes,
        utf8.encode('private-hive-derived-bytes'),
      );
    },
  );

  test(
    'resetting the Provider key does not affect review ciphertext',
    () async {
      final providerKeyStore = LocalMasterKeyStore(
        File('${directory.path}/.aitrans.provider.key'),
      );
      await providerKeyStore.create();
      final reviewKeys = FixedReviewKeyStore();
      final identity = ReviewIdentity.create(
        correctedTerm: 'provider-independent-term',
        actualSourceLanguage: TranslationSourceLanguage.en,
        targetLanguage: TranslationSourceLanguage.zh,
      );
      final repository = EncryptedReviewRepository(
        historyStore: HiveReviewCiphertextStore(historyBox),
        contentStore: HiveReviewCiphertextStore(contentBox),
        keyStore: reviewKeys,
      );
      await repository.recordTranslation(
        identity: identity,
        originalAlias: 'provider-independent-alias',
        translatedAt: DateTime.utc(2026, 7, 19, 8),
        content: ReviewEntryContent(
          sourceText: 'provider-independent-term',
          translationText: '独立密钥',
          primaryMeaning: '独立密钥',
          secondaryMeanings: const [],
        ),
      );

      await providerKeyStore.reset();

      expect(await providerKeyStore.loadExisting(), isNull);
      expect((await repository.find(identity))!.translationCount, 1);
      expect(reviewKeys.deleteCount, 0);
    },
  );
}

bool _containsBytes(List<int> haystack, List<int> needle) {
  if (needle.isEmpty) return true;
  for (var offset = 0; offset <= haystack.length - needle.length; offset++) {
    var matches = true;
    for (var index = 0; index < needle.length; index++) {
      if (haystack[offset + index] != needle[index]) {
        matches = false;
        break;
      }
    }
    if (matches) return true;
  }
  return false;
}

class FixedReviewKeyStore implements ReviewKeyStore {
  SecretKey? key;
  int deleteCount = 0;

  @override
  Future<SecretKey?> loadExisting() async => key;

  @override
  Future<SecretKey> create() async =>
      key ??= SecretKey(List<int>.filled(32, 17));

  @override
  Future<void> delete() async {
    deleteCount += 1;
    key = null;
  }
}
