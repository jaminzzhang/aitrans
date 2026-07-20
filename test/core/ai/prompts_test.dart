import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/core/ai/prompts.dart';
import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
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
      expect(prompt, contains('SOURCE_LANGUAGE:'));
      expect(
        prompt,
        contains(
          'REVIEW_CLASSIFICATION_VERSION: '
          '${TranslationPresentation.reviewClassificationContractVersion}',
        ),
      );
      expect(prompt, contains('REVIEW_CLASSIFICATION:'));
      for (final semanticClass in TranslationSemanticClass.values) {
        expect(prompt, contains(semanticClass.name));
      }
      expect(prompt, contains('第五行'));
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

  test(
    'review ranking prompt keeps the model inside the candidate contract',
    () {
      final request = ReviewAIRankRequest(
        candidates: [
          ReviewAICandidate(
            id: 'candidate-1',
            term: 'otter',
            sourceLanguage: 'en',
            targetLanguage: 'zh',
            translationCount: 2,
            consecutiveRememberedCount: 0,
            forgetCount: 1,
            overdueMinutes: 60,
            daysSinceLastReview: 2,
          ),
        ],
      );

      final prompt = Prompts.reviewRanking(request);

      expect(prompt, contains('恰好 1 项'));
      expect(prompt, contains('只能返回输入中已有的 id'));
      expect(prompt, contains('不得返回或修改复习进度'));
      expect(prompt, contains('"contractVersion":1'));
      expect(prompt, contains('"term":"otter"'));
      expect(prompt, isNot(contains('aliases')));
      expect(prompt, isNot(contains('translationText')));
      expect(prompt, isNot(contains('latestContent')));
    },
  );

  test('review text prompt requests usages and fictional dialogue only', () {
    final request = ReviewAITextContentRequest(
      term: 'break the ice',
      sourceLanguage: 'en',
      targetLanguage: 'zh',
      primaryMeaning: '打破僵局',
    );

    final prompt = Prompts.reviewTextContent(request);

    expect(prompt, contains('生活常用语'));
    expect(prompt, contains('影视化场景对白'));
    expect(prompt, contains('不得声称来自真实电影'));
    expect(prompt, contains('不得返回影片名'));
    expect(prompt, contains('"contractVersion":1'));
    expect(prompt, contains('"term":"break the ice"'));
    expect(prompt, isNot(contains('aliases')));
    expect(prompt, isNot(contains('translationCount')));
    expect(prompt, isNot(contains('history')));
  });
}
