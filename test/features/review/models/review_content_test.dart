import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:aitrans/features/review/models/review_content.dart';
import 'package:test/test.dart';

void main() {
  test('AI content is always identified as fictional screen dialogue', () {
    final content = ReviewTextContent.fromAI(
      ReviewAITextContentResponse(
        everydayUsages: [
          ReviewAIEverydayUsage(
            situation: '邻里见面',
            original: 'A game can break the ice.',
            translation: '游戏可以帮助大家打破僵局。',
          ),
        ],
        fictionalDialogue: ReviewAIFictionalDialogue(
          dialogue: 'We have to break the ice somehow.',
          translation: '我们总得想办法打破僵局。',
        ),
      ),
    );

    expect(content.movieContent.kind, ReviewMovieContentKind.fictionalScene);
    expect(content.movieContent.displayLabel, '影视化场景对白');
    expect(content.movieContent.workTitle, isNull);
    expect(content.movieContent.sourceReference, isNull);
    expect(content.movieContent.rightsReference, isNull);

    final restored = ReviewTextContent.fromJson(content.toJson());
    expect(restored.everydayUsages.single.situation, '邻里见面');
    expect(restored.movieContent.kind, ReviewMovieContentKind.fictionalScene);
  });

  test('approved quotes require work, source, and rights metadata', () {
    final approved = ReviewMovieContent.approvedQuote(
      workTitle: '已批准的虚构测试作品',
      sourceReference: 'approved-source-001',
      rightsReference: 'display-rights-001',
      dialogue: 'A licensed test quotation.',
      translation: '一条已许可的测试引文。',
    );

    expect(approved.kind, ReviewMovieContentKind.approvedQuote);
    expect(approved.displayLabel, '已批准影片台词');
    expect(
      () => ReviewMovieContent.approvedQuote(
        workTitle: '测试作品',
        sourceReference: '',
        rightsReference: 'rights-001',
        dialogue: 'Quote.',
        translation: '台词。',
      ),
      throwsArgumentError,
    );
  });
}
