import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:test/test.dart';

void main() {
  test('parses only the versioned bounded ranking response contract', () {
    final response = ReviewAIRankResponse.fromJson({
      'contractVersion': 1,
      'rankedItems': [
        {'id': 'candidate-1', 'reason': 'Frequently forgotten'},
        {'id': 'candidate-2', 'reason': 'Review is overdue'},
      ],
    });

    expect(response.rankedItems.map((item) => item.id), [
      'candidate-1',
      'candidate-2',
    ]);
    expect(
      () => response.rankedItems.add(
        ReviewAIRankedItem(id: 'candidate-3', reason: 'Mutation'),
      ),
      throwsUnsupportedError,
    );

    final invalidResponses = <Map<String, Object?>>[
      {
        'contractVersion': 2,
        'rankedItems': [
          {'id': 'candidate-1', 'reason': 'Wrong version'},
        ],
      },
      {'contractVersion': 1, 'rankedItems': 'not-a-list'},
      {
        'contractVersion': 1,
        'rankedItems': [
          {'id': 'candidate-1', 'reason': 'First'},
          {'id': 'candidate-1', 'reason': 'Duplicate'},
        ],
      },
      {
        'contractVersion': 1,
        'rankedItems': [
          {'id': 'candidate-1', 'reason': ''},
        ],
      },
      {
        'contractVersion': 1,
        'rankedItems': [
          {'id': 'candidate-1', 'reason': 'Valid', 'state': 'remembered'},
        ],
      },
    ];

    for (final invalid in invalidResponses) {
      expect(
        () => ReviewAIRankResponse.fromJson(invalid),
        throwsFormatException,
      );
    }
  });

  test('uses a minimal strict contract for generated review text', () {
    final request = ReviewAITextContentRequest(
      term: 'break the ice',
      sourceLanguage: 'en',
      targetLanguage: 'zh',
      primaryMeaning: '打破僵局',
    );

    expect(request.toJson(), {
      'contractVersion': 1,
      'term': 'break the ice',
      'sourceLanguage': 'en',
      'targetLanguage': 'zh',
      'primaryMeaning': '打破僵局',
    });

    final response = ReviewAITextContentResponse.fromJson({
      'contractVersion': 1,
      'everydayUsages': [
        {
          'situation': '第一次参加社区活动',
          'original': 'A quick game helped us break the ice.',
          'translation': '一个小游戏帮助我们打破了僵局。',
        },
      ],
      'fictionalDialogue': {
        'dialogue': 'We need something to break the ice.',
        'translation': '我们得想办法打破僵局。',
      },
    });

    expect(response.everydayUsages.single.situation, '第一次参加社区活动');
    expect(response.fictionalDialogue.dialogue, contains('break the ice'));

    expect(
      () => ReviewAITextContentResponse.fromJson({
        'contractVersion': 1,
        'everydayUsages': [
          {
            'situation': '派对',
            'original': 'Let us break the ice.',
            'translation': '让我们活跃一下气氛。',
          },
        ],
        'fictionalDialogue': {
          'movieTitle': 'AI 自报的影片名',
          'dialogue': 'Let us break the ice.',
          'translation': '让我们打破僵局。',
        },
      }),
      throwsFormatException,
    );
  });
}
