import 'package:aitrans/features/review/domain/review_eligibility.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:test/test.dart';

void main() {
  test('accepts a current-contract word with a known source language', () {
    final result = ReviewEligibility.evaluate(
      originalSource: 'serendipity',
      adoptedSource: 'serendipity',
      actualSourceLanguage: TranslationSourceLanguage.en,
      semanticClass: TranslationSemanticClass.word,
      classificationVersion:
          TranslationPresentation.reviewClassificationContractVersion,
    );

    expect(result.isEligible, isTrue);
    expect(result.exclusionReason, isNull);
  });

  test('applies local guards to both original and adopted source text', () {
    const familyEmoji = '👨‍👩‍👧‍👦';
    final exactlyEighty = List.filled(80, familyEmoji).join();
    final eightyOne = List.filled(81, familyEmoji).join();

    final cases =
        <
          ({
            String original,
            String adopted,
            ReviewEligibilityExclusionReason? reason,
          })
        >[
          (original: exactlyEighty, adopted: exactlyEighty, reason: null),
          (
            original: eightyOne,
            adopted: eightyOne,
            reason: ReviewEligibilityExclusionReason.exceedsGraphemeLimit,
          ),
          (
            original: 'ice\ncream',
            adopted: 'ice cream',
            reason: ReviewEligibilityExclusionReason.containsLineBreak,
          ),
          (
            original: 'ice cream',
            adopted: 'ice\ncream',
            reason: ReviewEligibilityExclusionReason.containsLineBreak,
          ),
          (
            original: 'Hello world. Goodbye world.',
            adopted: 'Hello world. Goodbye world.',
            reason: ReviewEligibilityExclusionReason.multipleSentenceBoundaries,
          ),
          (
            original: '你好。再见。',
            adopted: '你好。再见。',
            reason: ReviewEligibilityExclusionReason.multipleSentenceBoundaries,
          ),
          (original: 'Meet Dr. Smith', adopted: 'Meet Dr. Smith', reason: null),
          (
            original: 'Use e.g. examples',
            adopted: 'Use e.g. examples',
            reason: null,
          ),
          (original: 'U.S. English', adopted: 'U.S. English', reason: null),
          (original: 'version 1.2', adopted: 'version 1.2', reason: null),
          (original: '一期一会', adopted: '一期一会', reason: null),
          (original: '마음에 들다', adopted: '마음에 들다', reason: null),
        ];

    for (final testCase in cases) {
      final result = ReviewEligibility.evaluate(
        originalSource: testCase.original,
        adoptedSource: testCase.adopted,
        actualSourceLanguage: TranslationSourceLanguage.en,
        semanticClass: TranslationSemanticClass.phrase,
        classificationVersion:
            TranslationPresentation.reviewClassificationContractVersion,
      );

      expect(
        result.exclusionReason,
        testCase.reason,
        reason: 'original=${testCase.original}',
      );
      expect(result.isEligible, testCase.reason == null);
    }
  });

  test('returns stable reasons for contract and semantic exclusions', () {
    final cases =
        <
          ({
            String original,
            String adopted,
            TranslationSourceLanguage language,
            TranslationSemanticClass semanticClass,
            int? version,
            ReviewEligibilityExclusionReason? reason,
          })
        >[
          (
            original: 'take care',
            adopted: 'take care',
            language: TranslationSourceLanguage.en,
            semanticClass: TranslationSemanticClass.phrase,
            version: 1,
            reason: null,
          ),
          (
            original: 'A complete sentence.',
            adopted: 'A complete sentence.',
            language: TranslationSourceLanguage.en,
            semanticClass: TranslationSemanticClass.sentence,
            version: 1,
            reason: ReviewEligibilityExclusionReason.semanticClassNotReviewable,
          ),
          (
            original: 'A paragraph',
            adopted: 'A paragraph',
            language: TranslationSourceLanguage.en,
            semanticClass: TranslationSemanticClass.paragraph,
            version: 1,
            reason: ReviewEligibilityExclusionReason.semanticClassNotReviewable,
          ),
          (
            original: 'unclear',
            adopted: 'unclear',
            language: TranslationSourceLanguage.en,
            semanticClass: TranslationSemanticClass.unknown,
            version: 1,
            reason: ReviewEligibilityExclusionReason.semanticClassNotReviewable,
          ),
          (
            original: 'legacy',
            adopted: 'legacy',
            language: TranslationSourceLanguage.en,
            semanticClass: TranslationSemanticClass.word,
            version: null,
            reason: ReviewEligibilityExclusionReason
                .unsupportedClassificationVersion,
          ),
          (
            original: 'future',
            adopted: 'future',
            language: TranslationSourceLanguage.en,
            semanticClass: TranslationSemanticClass.word,
            version: 2,
            reason: ReviewEligibilityExclusionReason
                .unsupportedClassificationVersion,
          ),
          (
            original: '同形词',
            adopted: '同形词',
            language: TranslationSourceLanguage.unknown,
            semanticClass: TranslationSemanticClass.word,
            version: 1,
            reason: ReviewEligibilityExclusionReason.unknownSourceLanguage,
          ),
          (
            original: '   ',
            adopted: 'word',
            language: TranslationSourceLanguage.en,
            semanticClass: TranslationSemanticClass.word,
            version: 1,
            reason: ReviewEligibilityExclusionReason.emptySource,
          ),
        ];

    for (final testCase in cases) {
      final result = ReviewEligibility.evaluate(
        originalSource: testCase.original,
        adoptedSource: testCase.adopted,
        actualSourceLanguage: testCase.language,
        semanticClass: testCase.semanticClass,
        classificationVersion: testCase.version,
      );

      expect(result.exclusionReason, testCase.reason);
      expect(result.isEligible, testCase.reason == null);
    }
  });
}
