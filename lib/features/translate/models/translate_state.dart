import 'package:flutter/foundation.dart';
import '../../../core/ai/ai_provider.dart';

/// 翻译状态
sealed class TranslateState {
  const TranslateState();
}

/// 空状态
class TranslateEmpty extends TranslateState {
  const TranslateEmpty();
}

/// 加载中
class TranslateLoading extends TranslateState {
  const TranslateLoading();
}

/// 流式输出中
class TranslateStreaming extends TranslateState {
  final String text;
  const TranslateStreaming(this.text);
}

/// 翻译完成
class TranslateComplete extends TranslateState {
  final String text;
  const TranslateComplete(this.text);
}

/// 翻译出错
class TranslateError extends TranslateState {
  final String message;
  const TranslateError(this.message);
}

/// 辅助内容状态
@immutable
class AuxiliaryState {
  final List<Example> examples;
  final List<MovieQuote> movieQuotes;
  final List<ExamItem> examItems;
  final bool isLoading;

  const AuxiliaryState({
    this.examples = const [],
    this.movieQuotes = const [],
    this.examItems = const [],
    this.isLoading = false,
  });

  AuxiliaryState copyWith({
    List<Example>? examples,
    List<MovieQuote>? movieQuotes,
    List<ExamItem>? examItems,
    bool? isLoading,
  }) {
    return AuxiliaryState(
      examples: examples ?? this.examples,
      movieQuotes: movieQuotes ?? this.movieQuotes,
      examItems: examItems ?? this.examItems,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
