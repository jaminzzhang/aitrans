import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('review image capability is unsupported by default', () async {
    final provider = _DefaultProvider();
    final request = ReviewAIImageRequest(
      term: 'break the ice',
      sourceLanguage: 'en',
      targetLanguage: 'zh',
      primaryMeaning: '打破僵局',
    );

    expect(provider.reviewImageCapability, ReviewAIImageCapability.unsupported);
    await expectLater(
      provider.generateReviewImage(request),
      throwsA(
        isA<AIProviderException>().having(
          (error) => error.code,
          'code',
          AIProviderErrorCode.unsupportedCapability,
        ),
      ),
    );
  });

  test('review image response only accepts bounded png or jpeg bytes', () {
    expect(
      ReviewAIImageResponse(
        mediaType: 'image/png',
        bytes: const [137, 80, 78, 71, 13, 10, 26, 10],
      ),
      isA<ReviewAIImageResponse>(),
    );
    expect(
      () =>
          ReviewAIImageResponse(mediaType: 'image/png', bytes: const [1, 2, 3]),
      throwsArgumentError,
    );
    expect(
      () =>
          ReviewAIImageResponse(mediaType: 'text/html', bytes: const [1, 2, 3]),
      throwsArgumentError,
    );
    expect(
      () => ReviewAIImageResponse(mediaType: 'image/png', bytes: const []),
      throwsArgumentError,
    );
    expect(
      () => ReviewAIImageResponse(
        mediaType: 'image/jpeg',
        bytes: List<int>.filled(ReviewAIImageResponse.maxBytes + 1, 0),
      ),
      throwsArgumentError,
    );
  });
}

class _DefaultProvider extends AIProvider {
  @override
  String get name => 'default-test-provider';

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
