import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:test/test.dart';

void main() {
  final identity = ReviewIdentity.create(
    correctedTerm: 'the',
    actualSourceLanguage: TranslationSourceLanguage.en,
    targetLanguage: TranslationSourceLanguage.zh,
  );
  final firstTranslatedAt = DateTime.utc(2026, 7, 1, 8);
  final firstContent = ReviewEntryContent(
    sourceText: 'the',
    translationText: '这个；那个',
    primaryMeaning: '这个；那个',
    partOfSpeech: 'article',
    pronunciation: '/ðə/',
    secondaryMeanings: const ['表示特指'],
  );

  test('first translation creates a typed entry with neutral progress', () {
    final entry = ReviewEntry.firstTranslation(
      identity: identity,
      originalAlias: 'teh',
      translatedAt: firstTranslatedAt,
      content: firstContent,
    );

    expect(entry.identity, identity);
    expect(entry.aliases, {'teh'});
    expect(entry.createdAt, firstTranslatedAt);
    expect(entry.latestTranslatedAt, firstTranslatedAt);
    expect(entry.translationCount, 1);
    expect(entry.latestContent, firstContent);
    expect(entry.consecutiveRememberedCount, 0);
    expect(entry.forgetCount, 0);
    expect(entry.lastReviewedAt, isNull);
    expect(entry.nextReviewAt, isNull);
    expect(entry.forcedDue, isFalse);
    expect(entry.generation, 0);
  });

  test(
    'retranslation from another provider merges aliases and preserves progress',
    () {
      final lastReviewedAt = DateTime.utc(2026, 7, 2, 9);
      final nextReviewAt = DateTime.utc(2026, 7, 9, 9);
      final entry = ReviewEntry(
        identity: identity,
        aliases: const {'teh'},
        createdAt: firstTranslatedAt,
        latestTranslatedAt: firstTranslatedAt,
        translationCount: 3,
        latestContent: firstContent,
        consecutiveRememberedCount: 2,
        forgetCount: 1,
        lastReviewedAt: lastReviewedAt,
        nextReviewAt: nextReviewAt,
        forcedDue: false,
        generation: 7,
      );
      final providerBContent = ReviewEntryContent(
        sourceText: 'the',
        translationText: '该；这',
        primaryMeaning: '该；这',
        partOfSpeech: 'determiner',
        pronunciation: '/ðiː/',
        secondaryMeanings: const ['表示已提及的人或事物'],
      );
      final translatedAt = DateTime.utc(2026, 7, 3, 10);

      final updated = entry.recordTranslation(
        originalAlias: 'the',
        translatedAt: translatedAt,
        content: providerBContent,
      );

      expect(updated.identity, same(identity));
      expect(updated.aliases, {'teh', 'the'});
      expect(updated.translationCount, 4);
      expect(updated.latestTranslatedAt, translatedAt);
      expect(updated.latestContent, providerBContent);
      expect(updated.createdAt, firstTranslatedAt);
      expect(updated.consecutiveRememberedCount, 2);
      expect(updated.forgetCount, 1);
      expect(updated.lastReviewedAt, lastReviewedAt);
      expect(updated.nextReviewAt, nextReviewAt);
      expect(updated.forcedDue, isFalse);
      expect(updated.generation, 7);
    },
  );

  test(
    'an older completion cannot replace the latest timestamp or content',
    () {
      final entry = ReviewEntry.firstTranslation(
        identity: identity,
        originalAlias: 'the',
        translatedAt: firstTranslatedAt,
        content: firstContent,
      );
      final staleContent = ReviewEntryContent(
        sourceText: 'the',
        translationText: '过期内容',
        primaryMeaning: '过期内容',
        secondaryMeanings: const [],
      );

      final updated = entry.recordTranslation(
        originalAlias: 'THE',
        translatedAt: firstTranslatedAt.subtract(const Duration(minutes: 1)),
        content: staleContent,
      );

      expect(updated.translationCount, 2);
      expect(updated.aliases, {'the', 'THE'});
      expect(updated.latestTranslatedAt, firstTranslatedAt);
      expect(updated.latestContent, firstContent);
    },
  );

  test('entry and content collections are immutable snapshots', () {
    final aliases = <String>{'teh'};
    final secondaryMeanings = <String>['表示特指'];
    final content = ReviewEntryContent(
      sourceText: 'the',
      translationText: '这个',
      primaryMeaning: '这个',
      secondaryMeanings: secondaryMeanings,
    );
    final entry = ReviewEntry.firstTranslation(
      identity: identity,
      originalAlias: aliases.single,
      translatedAt: firstTranslatedAt,
      content: content,
    );

    aliases.add('the');
    secondaryMeanings.add('新增内容');

    expect(entry.aliases, {'teh'});
    expect(entry.latestContent.secondaryMeanings, ['表示特指']);
    expect(() => entry.aliases.add('blocked'), throwsUnsupportedError);
    expect(
      () => entry.latestContent.secondaryMeanings.add('blocked'),
      throwsUnsupportedError,
    );
  });

  test('rejects content that belongs to a different learning identity', () {
    final mismatchedContent = ReviewEntryContent(
      sourceText: 'banana',
      translationText: '香蕉',
      primaryMeaning: '香蕉',
      secondaryMeanings: const [],
    );

    expect(
      () => ReviewEntry.firstTranslation(
        identity: identity,
        originalAlias: 'banana',
        translatedAt: firstTranslatedAt,
        content: mismatchedContent,
      ),
      throwsArgumentError,
    );
  });
}
