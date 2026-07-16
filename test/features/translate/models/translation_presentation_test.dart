import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:test/test.dart';

void main() {
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
