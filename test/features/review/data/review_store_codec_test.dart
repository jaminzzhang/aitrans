import 'dart:convert';

import 'package:aitrans/features/review/data/review_store_codec.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  final codec = ReviewStoreCodec();
  final key = SecretKey(List<int>.generate(32, (index) => index));
  final identity = ReviewIdentity.create(
    correctedTerm: 'private-otter-lexeme',
    actualSourceLanguage: TranslationSourceLanguage.en,
    targetLanguage: TranslationSourceLanguage.zh,
  );
  final entry = ReviewEntry(
    identity: identity,
    aliases: const {'private-otter-alias'},
    createdAt: DateTime.utc(2026, 7, 18, 8),
    latestTranslatedAt: DateTime.utc(2026, 7, 19, 9),
    translationCount: 3,
    latestContent: ReviewEntryContent(
      sourceText: 'private-otter-lexeme',
      translationText: '隐私水獭译文',
      primaryMeaning: '隐私水獭词义',
      partOfSpeech: 'noun',
      pronunciation: '/ˈɒtə/',
      secondaryMeanings: const ['隐私水獭次义'],
    ),
    consecutiveRememberedCount: 2,
    forgetCount: 1,
    lastReviewedAt: DateTime.utc(2026, 7, 19, 7),
    nextReviewAt: DateTime.utc(2026, 7, 26, 7),
    forcedDue: true,
    generation: 4,
    appliedFeedbackEventIds: const {
      'feedback-private-otter-1',
      'feedback-private-otter-2',
    },
  );

  test('encrypts every review field and restores the typed entry', () async {
    final envelope = await codec.encryptEntry(entry: entry, key: key);
    final rawStorage = jsonEncode({codec.entryStorageKey(identity): envelope});

    expect(rawStorage, isNot(contains('private-otter-lexeme')));
    expect(rawStorage, isNot(contains('private-otter-alias')));
    expect(rawStorage, isNot(contains('隐私水獭')));
    expect(
      envelope.keys,
      containsAll(<String>{
        'schemaVersion',
        'algorithm',
        'keyId',
        'nonce',
        'cipherText',
        'mac',
      }),
    );

    final restored = await codec.decryptEntry(
      envelope: envelope,
      expectedIdentity: identity,
      key: key,
    );

    expect(restored.identity, identity);
    expect(restored.aliases, entry.aliases);
    expect(restored.createdAt, entry.createdAt);
    expect(restored.latestTranslatedAt, entry.latestTranslatedAt);
    expect(restored.translationCount, entry.translationCount);
    expect(restored.latestContent.sourceText, entry.latestContent.sourceText);
    expect(
      restored.latestContent.translationText,
      entry.latestContent.translationText,
    );
    expect(
      restored.latestContent.secondaryMeanings,
      entry.latestContent.secondaryMeanings,
    );
    expect(restored.consecutiveRememberedCount, 2);
    expect(restored.forgetCount, 1);
    expect(restored.lastReviewedAt, entry.lastReviewedAt);
    expect(restored.nextReviewAt, entry.nextReviewAt);
    expect(restored.forcedDue, isTrue);
    expect(restored.generation, 4);
    expect(restored.appliedFeedbackEventIds, entry.appliedFeedbackEventIds);
  });

  test('AAD prevents moving ciphertext to another identity', () async {
    final envelope = await codec.encryptEntry(entry: entry, key: key);
    final anotherIdentity = ReviewIdentity.create(
      correctedTerm: 'different-otter-lexeme',
      actualSourceLanguage: TranslationSourceLanguage.en,
      targetLanguage: TranslationSourceLanguage.zh,
    );

    expect(
      () => codec.decryptEntry(
        envelope: envelope,
        expectedIdentity: anotherIdentity,
        key: key,
      ),
      throwsA(isA<ReviewStoreCorruptedException>()),
    );
  });

  test('rejects modified ciphertext without exposing its contents', () async {
    final envelope = await codec.encryptEntry(entry: entry, key: key);
    final cipherText = base64Decode(envelope['cipherText']! as String);
    cipherText[0] ^= 0x01;
    final tampered = <String, Object>{
      ...envelope,
      'cipherText': base64Encode(cipherText),
    };

    expect(
      () => codec.decryptEntry(
        envelope: tampered,
        expectedIdentity: identity,
        key: key,
      ),
      throwsA(isA<ReviewStoreCorruptedException>()),
    );
  });

  test('rejects a key with a different opaque key id', () async {
    final envelope = await codec.encryptEntry(entry: entry, key: key);
    final wrongKey = SecretKey(List<int>.filled(32, 0xff));

    expect(
      () => codec.decryptEntry(
        envelope: envelope,
        expectedIdentity: identity,
        key: wrongKey,
      ),
      throwsA(isA<ReviewStoreCorruptedException>()),
    );
  });
}
