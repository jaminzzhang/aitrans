import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:test/test.dart';

void main() {
  test('splits the primary meaning from normalized secondary meanings', () {
    final presentation = TranslationPresentation.parse(
      '意外发现\n- 偶然发现\n• 机缘巧合\n3. 意外收获',
    );

    expect(presentation.primaryMeaning, '意外发现');
    expect(presentation.secondaryMeanings, ['偶然发现', '机缘巧合', '意外收获']);
  });

  test('keeps a sentence-only translation as the primary meaning', () {
    final presentation = TranslationPresentation.parse('这是一个完整的句子。');

    expect(presentation.primaryMeaning, '这是一个完整的句子。');
    expect(presentation.secondaryMeanings, isEmpty);
  });
}
