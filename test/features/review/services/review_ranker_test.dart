import 'dart:async';

import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:aitrans/features/review/services/review_ranker.dart';
import 'package:test/test.dart';

void main() {
  test('a ranking timeout cancels the dedicated provider request', () async {
    final provider = _HangingAIProvider();
    final ranker = AIReviewRanker(
      provider: provider,
      timeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      ranker.rank(_request()),
      throwsA(
        isA<ReviewRankerException>().having(
          (error) => error.failure,
          'failure',
          ReviewRankerFailure.timeout,
        ),
      ),
    );
    expect(provider.cancelCount, 1);
  });
}

ReviewAIRankRequest _request() {
  return ReviewAIRankRequest(
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
}

class _HangingAIProvider extends AIProvider {
  final Completer<ReviewAIRankResponse> pending = Completer();
  int cancelCount = 0;

  @override
  String get name => 'Hanging';

  @override
  Future<void> cancelActiveRequests() async {
    cancelCount++;
  }

  @override
  Future<ReviewAIRankResponse> rankReviewCandidates(
    ReviewAIRankRequest request,
  ) => pending.future;

  @override
  Future<bool> testConnection() async => true;

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) => const Stream.empty();

  @override
  Stream<List<Example>> getExamples(String word) => const Stream.empty();

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();

  @override
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();
}
