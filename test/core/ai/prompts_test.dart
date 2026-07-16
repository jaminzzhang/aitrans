import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/core/ai/prompts.dart';
import 'package:test/test.dart';

void main() {
  test(
    'translation prompt requests correction and translation in one response',
    () {
      final prompt = Prompts.translateSystem(from: 'en', to: 'zh');

      expect(prompt, contains('CORRECTION:'));
      expect(prompt, contains('无需更正'));
      expect(prompt, contains('拼写、语法或明显错别字'));
      expect(prompt, contains('数字、URL、代码、标识符'));
      expect(prompt, contains('不确定的专有名词'));
      expect(prompt, contains('同一次响应'));
      expect(prompt, contains('第二行只输出最主要、最常用的词义'));
      expect(prompt, contains('POS:'));
      expect(prompt, contains('PRON:'));
      expect(prompt, contains('词性'));
      expect(prompt, contains('读音'));
      expect(prompt, contains('完整句子或段落'));
    },
  );

  test('enrichment prompt requests all sections in one JSON object', () {
    final prompt = Prompts.translationEnrichment('hello');

    expect(prompt, contains('"examples"'));
    expect(prompt, contains('"movieQuotes"'));
    expect(prompt, contains('"examItems"'));
    expect(prompt, contains('一次生成'));
  });

  test('translation enrichment parses all sections from one response', () {
    final enrichment = TranslationEnrichment.fromJson({
      'examples': [
        {'scene': '日常', 'original': 'Hello.', 'translation': '你好。'},
      ],
      'movieQuotes': [
        {'movie': '电影', 'quote': 'Hello.', 'translation': '你好。'},
      ],
      'examItems': [
        {'source': '考试', 'question': 'Hello?', 'answer': 'Hello.'},
      ],
    });

    expect(enrichment.examples.single.scene, '日常');
    expect(enrichment.movieQuotes.single.movie, '电影');
    expect(enrichment.examItems.single.source, '考试');
  });
}
