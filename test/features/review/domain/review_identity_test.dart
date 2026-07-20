import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:test/test.dart';

void main() {
  group('ReviewIdentity normalization', () {
    final cases =
        <
          ({
            String input,
            TranslationSourceLanguage sourceLanguage,
            String expected,
          })
        >[
          (
            input: '  ＨＥＬＬＯ\t　WORLD  ',
            sourceLanguage: TranslationSourceLanguage.en,
            expected: 'hello world',
          ),
          (
            input: 'Cafe\u0301',
            sourceLanguage: TranslationSourceLanguage.fr,
            expected: 'café',
          ),
          (
            input: 'ｶﾀｶﾅ',
            sourceLanguage: TranslationSourceLanguage.ja,
            expected: 'カタカナ',
          ),
          (
            input: 'ПРИВЕТ',
            sourceLanguage: TranslationSourceLanguage.ru,
            expected: 'привет',
          ),
          (
            input: 'ẞ',
            sourceLanguage: TranslationSourceLanguage.de,
            expected: 'ß',
          ),
        ];

    for (final testCase in cases) {
      test('normalizes ${testCase.input}', () {
        final identity = ReviewIdentity.create(
          correctedTerm: testCase.input,
          actualSourceLanguage: testCase.sourceLanguage,
          targetLanguage: TranslationSourceLanguage.zh,
        );

        expect(identity.normalizedTerm, testCase.expected);
      });
    }

    test('equivalent forms have stable equality and hash codes', () {
      final decomposed = ReviewIdentity.create(
        correctedTerm: '  Cafe\u0301 ',
        actualSourceLanguage: TranslationSourceLanguage.fr,
        targetLanguage: TranslationSourceLanguage.en,
      );
      final composed = ReviewIdentity.create(
        correctedTerm: 'CAFÉ',
        actualSourceLanguage: TranslationSourceLanguage.fr,
        targetLanguage: TranslationSourceLanguage.en,
      );

      expect(decomposed, composed);
      expect(decomposed.hashCode, composed.hashCode);
    });
  });

  test('same spelling in a different language or direction stays separate', () {
    final enToZh = ReviewIdentity.create(
      correctedTerm: 'gift',
      actualSourceLanguage: TranslationSourceLanguage.en,
      targetLanguage: TranslationSourceLanguage.zh,
    );
    final deToZh = ReviewIdentity.create(
      correctedTerm: 'Gift',
      actualSourceLanguage: TranslationSourceLanguage.de,
      targetLanguage: TranslationSourceLanguage.zh,
    );
    final enToJa = ReviewIdentity.create(
      correctedTerm: 'gift',
      actualSourceLanguage: TranslationSourceLanguage.en,
      targetLanguage: TranslationSourceLanguage.ja,
    );

    expect(enToZh, isNot(deToZh));
    expect(enToZh, isNot(enToJa));
  });

  test(
    'serialization is versioned and contains only stable identity fields',
    () {
      final identity = ReviewIdentity.create(
        correctedTerm: '  ＨＥＬＬＯ  ',
        actualSourceLanguage: TranslationSourceLanguage.en,
        targetLanguage: TranslationSourceLanguage.zh,
      );

      final json = identity.toJson();

      expect(json, {
        'schemaVersion': 1,
        'term': 'hello',
        'sourceLanguage': 'en',
        'targetLanguage': 'zh',
      });
      expect(json.keys, isNot(contains(anyOf('provider', 'model'))));
      expect(ReviewIdentity.fromJson(json), identity);
    },
  );

  test('rejects empty terms, unknown languages, and unsupported schemas', () {
    expect(
      () => ReviewIdentity.create(
        correctedTerm: '　 ',
        actualSourceLanguage: TranslationSourceLanguage.en,
        targetLanguage: TranslationSourceLanguage.zh,
      ),
      throwsArgumentError,
    );
    expect(
      () => ReviewIdentity.create(
        correctedTerm: 'word',
        actualSourceLanguage: TranslationSourceLanguage.unknown,
        targetLanguage: TranslationSourceLanguage.zh,
      ),
      throwsArgumentError,
    );
    expect(
      () => ReviewIdentity.fromJson({
        'schemaVersion': 2,
        'term': 'word',
        'sourceLanguage': 'en',
        'targetLanguage': 'zh',
      }),
      throwsFormatException,
    );
  });
}
