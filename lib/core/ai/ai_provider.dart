import 'dart:async';

import 'ai_chat.dart';
import 'review_ai_models.dart';

enum AIProviderErrorCode {
  invalidConfiguration,
  requestFailed,
  invalidResponse,
  cancelled,
  unsupportedCapability,
  safetyRejected,
}

class AIProviderException implements Exception {
  final AIProviderErrorCode code;
  final String message;

  const AIProviderException({required this.code, required this.message});

  @override
  String toString() => message;
}

/// 翻译结果
class TranslationResult {
  final String text;
  final bool isComplete;

  TranslationResult({required this.text, required this.isComplete});
}

/// 场景例句
class Example {
  final String scene;
  final String original;
  final String translation;

  Example({
    required this.scene,
    required this.original,
    required this.translation,
  });
}

/// 电影台词
class MovieQuote {
  final String movie;
  final String quote;
  final String translation;

  MovieQuote({
    required this.movie,
    required this.quote,
    required this.translation,
  });
}

/// 考试真题
class ExamItem {
  final String source;
  final String question;
  final String answer;

  ExamItem({
    required this.source,
    required this.question,
    required this.answer,
  });
}

/// 主译文完成后一次性加载的扩展内容。
class TranslationEnrichment {
  final List<Example> examples;
  final List<MovieQuote> movieQuotes;
  final List<ExamItem> examItems;

  const TranslationEnrichment({
    this.examples = const [],
    this.movieQuotes = const [],
    this.examItems = const [],
  });

  factory TranslationEnrichment.fromJson(Map<String, dynamic> json) {
    final examples = _jsonObjects(json['examples'])
        .map(
          (item) => Example(
            scene: item['scene'] as String? ?? '',
            original: item['original'] as String? ?? '',
            translation: item['translation'] as String? ?? '',
          ),
        )
        .toList();
    final movieQuotes = _jsonObjects(json['movieQuotes'])
        .map(
          (item) => MovieQuote(
            movie: item['movie'] as String? ?? '',
            quote: item['quote'] as String? ?? '',
            translation: item['translation'] as String? ?? '',
          ),
        )
        .toList();
    final examItems = _jsonObjects(json['examItems'])
        .map(
          (item) => ExamItem(
            source: item['source'] as String? ?? '',
            question: item['question'] as String? ?? '',
            answer: item['answer'] as String? ?? '',
          ),
        )
        .toList();
    return TranslationEnrichment(
      examples: examples,
      movieQuotes: movieQuotes,
      examItems: examItems,
    );
  }
}

List<Map<String, dynamic>> _jsonObjects(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => item.cast<String, dynamic>())
      .toList();
}

/// AI Provider 抽象接口
abstract class AIProvider {
  /// Provider 名称
  String get name;

  /// Stable, non-secret identity for cache isolation.
  String get cacheNamespace => name;

  /// 测试连接
  Future<bool> testConnection();

  Stream<AIChatEvent> chat(AIChatRequest request) => Stream.error(
    const AIProviderException(
      code: AIProviderErrorCode.unsupportedCapability,
      message: 'This provider does not support tool calling.',
    ),
  );

  /// Abort all in-flight requests owned by this provider instance.
  Future<void> cancelActiveRequests() async {}

  /// Release provider-owned resources.
  void close() {}

  /// 流式翻译
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  });

  Future<ReviewAIRankResponse> rankReviewCandidates(
    ReviewAIRankRequest request,
  ) => Future.error(
    const AIProviderException(
      code: AIProviderErrorCode.unsupportedCapability,
      message: 'This provider does not support review ranking.',
    ),
  );

  Future<ReviewAITextContentResponse> generateReviewTextContent(
    ReviewAITextContentRequest request,
  ) => Future.error(
    const AIProviderException(
      code: AIProviderErrorCode.unsupportedCapability,
      message: 'This provider does not support review text generation.',
    ),
  );

  /// Image generation is opt-in for the exact configured provider/model.
  ReviewAIImageCapability get reviewImageCapability =>
      ReviewAIImageCapability.unsupported;

  Future<ReviewAIImageResponse> generateReviewImage(
    ReviewAIImageRequest request,
  ) => Future.error(
    const AIProviderException(
      code: AIProviderErrorCode.unsupportedCapability,
      message: 'This provider does not support review image generation.',
    ),
  );

  /// 一次请求返回场景例句、电影台词和考试真题。
  Stream<TranslationEnrichment> enrichTranslation(String text) => Stream.error(
    const AIProviderException(
      code: AIProviderErrorCode.unsupportedCapability,
      message: 'This provider does not support translation enrichment.',
    ),
  );

  /// 获取场景例句
  Stream<List<Example>> getExamples(String word);

  /// 获取电影台词
  Stream<List<MovieQuote>> getMovieQuotes(String word);

  /// 获取考试真题
  Stream<List<ExamItem>> getExamItems(String word);
}
