import 'dart:async';

import 'ai_chat.dart';

enum AIProviderErrorCode {
  invalidConfiguration,
  requestFailed,
  invalidResponse,
  cancelled,
  unsupportedCapability,
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

  /// 获取场景例句
  Stream<List<Example>> getExamples(String word);

  /// 获取电影台词
  Stream<List<MovieQuote>> getMovieQuotes(String word);

  /// 获取考试真题
  Stream<List<ExamItem>> getExamItems(String word);
}
