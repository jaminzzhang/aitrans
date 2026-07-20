import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:test/test.dart';

void main() {
  test(
    'parses versioned review metadata without exposing it as translation',
    () {
      final presentation = TranslationPresentation.parse(
        'CORRECTION: -\n'
        'SOURCE_LANGUAGE: en\n'
        'REVIEW_CLASSIFICATION_VERSION: 1\n'
        'REVIEW_CLASSIFICATION: word\n'
        '猫\n'
        'POS: noun',
        originalSource: 'cat',
      );

      expect(presentation.actualSourceLanguage, TranslationSourceLanguage.en);
      expect(presentation.reviewClassificationVersion, 1);
      expect(presentation.semanticClass, TranslationSemanticClass.word);
      expect(presentation.primaryMeaning, '猫');
      expect(presentation.translationText, '猫\nPOS: noun');
      expect(TranslationPresentation.outputContractVersion, 5);
    },
  );

  test('does not infer review metadata from legacy or malformed responses', () {
    final cases =
        <({String response, TranslationSourceLanguage language, int? version})>[
          (
            response: '猫',
            language: TranslationSourceLanguage.unknown,
            version: null,
          ),
          (
            response:
                'SOURCE_LANGUAGE: english\n'
                'REVIEW_CLASSIFICATION_VERSION: 1\n'
                'REVIEW_CLASSIFICATION: word\n'
                '猫',
            language: TranslationSourceLanguage.unknown,
            version: 1,
          ),
          (
            response:
                'SOURCE_LANGUAGE: en\n'
                'REVIEW_CLASSIFICATION_VERSION: 2\n'
                'REVIEW_CLASSIFICATION: word\n'
                '猫',
            language: TranslationSourceLanguage.en,
            version: 2,
          ),
          (
            response:
                'SOURCE_LANGUAGE: en\n'
                'REVIEW_CLASSIFICATION_VERSION: 1\n'
                'REVIEW_CLASSIFICATION: idiom\n'
                '猫',
            language: TranslationSourceLanguage.unknown,
            version: 1,
          ),
          (
            response:
                'SOURCE_LANGUAGE: en\n'
                'REVIEW_CLASSIFICATION_VERSION: 1\n'
                'REVIEW_CLASSIFICATION: word\n'
                'REVIEW_CLASSIFICATION: phrase\n'
                '猫',
            language: TranslationSourceLanguage.unknown,
            version: 1,
          ),
        ];

    for (final testCase in cases) {
      final presentation = TranslationPresentation.parse(testCase.response);

      expect(presentation.actualSourceLanguage, testCase.language);
      expect(presentation.reviewClassificationVersion, testCase.version);
      expect(
        presentation.semanticClass,
        TranslationSemanticClass.unknown,
        reason: testCase.response,
      );
      expect(presentation.primaryMeaning, '猫');
    }
  });

  test('hides incomplete review protocol prefixes while streaming', () {
    for (final response in [
      'CORRECTION: -\nSOURCE_',
      'CORRECTION: -\nSOURCE_LANGUAGE: en\nREVIEW_CLASS',
    ]) {
      final presentation = TranslationPresentation.parse(
        response,
        originalSource: 'cat',
      );

      expect(presentation.primaryMeaning, isEmpty, reason: response);
      expect(presentation.translationText, isEmpty, reason: response);
    }
  });

  test('separates a valid correction from the translated presentation', () {
    final presentation = TranslationPresentation.parse(
      'CORRECTION: the cat\n猫\nPOS: noun\nPRON: /kæt/\n- 猫科动物',
      originalSource: 'teh cat',
    );

    expect(presentation.correctedSource, 'the cat');
    expect(presentation.adoptedSource, 'the cat');
    expect(presentation.primaryMeaning, '猫');
    expect(presentation.partOfSpeech, 'noun');
    expect(presentation.pronunciation, '/kæt/');
    expect(presentation.secondaryMeanings, ['猫科动物']);
  });

  test('rejects a correction that changes protected source tokens', () {
    const original = 'Pay 10 at https://example.test for order_id';
    final presentation = TranslationPresentation.parse(
      'CORRECTION: Pay 20 at https://other.test for orderId\n支付订单。',
      originalSource: original,
    );

    expect(presentation.correctedSource, isNull);
    expect(presentation.adoptedSource, original);
    expect(presentation.primaryMeaning, '支付订单。');
  });

  test('hides an incomplete correction protocol prefix while streaming', () {
    final presentation = TranslationPresentation.parse(
      'CORREC',
      originalSource: 'teh cat',
    );

    expect(presentation.primaryMeaning, isEmpty);
    expect(presentation.translationText, isEmpty);
    expect(presentation.adoptedSource, 'teh cat');
  });

  test('splits the primary meaning from normalized secondary meanings', () {
    final presentation = TranslationPresentation.parse(
      '意外发现\nPOS: noun\nPRON: /ˌserənˈdɪpəti/\n- 偶然发现\n• 机缘巧合\n3. 意外收获',
    );

    expect(presentation.primaryMeaning, '意外发现');
    expect(presentation.partOfSpeech, 'noun');
    expect(presentation.pronunciation, '/ˌserənˈdɪpəti/');
    expect(presentation.secondaryMeanings, ['偶然发现', '机缘巧合', '意外收获']);
  });

  test('keeps a sentence-only translation as the primary meaning', () {
    final presentation = TranslationPresentation.parse('这是一个完整的句子。');

    expect(presentation.primaryMeaning, '这是一个完整的句子。');
    expect(presentation.partOfSpeech, isNull);
    expect(presentation.pronunciation, isNull);
    expect(presentation.secondaryMeanings, isEmpty);
  });

  test('treats unavailable lexical metadata as absent', () {
    final presentation = TranslationPresentation.parse(
      '上下文\nPOS: -\nPRON: -\n- 语境',
    );

    expect(presentation.partOfSpeech, isNull);
    expect(presentation.pronunciation, isNull);
    expect(presentation.secondaryMeanings, ['语境']);
  });
}
