import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/ai/ai.dart';
import '../../../core/cache/translation_cache.dart';
import '../../../core/config/ai_config.dart';
import '../models/translate_state.dart';

/// AI 配置 Provider
final aiConfigProvider = StateProvider<AIConfig>((ref) {
  return AIConfig(providerType: ProviderType.ollama);
});

/// AI Provider 实例
final aiProviderProvider = Provider<AIProvider>((ref) {
  final config = ref.watch(aiConfigProvider);
  return ProviderFactory.create(config);
});

/// 翻译缓存 Provider
final translationCacheProvider = Provider<TranslationCache?>((ref) {
  try {
    if (Hive.isBoxOpen('translation_cache')) {
      final box = Hive.box<CachedTranslation>('translation_cache');
      return TranslationCache(box);
    }
  } catch (e) {
    // Box not available
  }
  return null;
});

/// 翻译控制器
class TranslateController extends StateNotifier<TranslateState> {
  final AIProvider _aiProvider;
  final TranslationCache? _cache;
  Timer? _debounceTimer;
  StreamSubscription? _translateSubscription;

  TranslateController(this._aiProvider, this._cache)
      : super(const TranslateEmpty());

  /// 输入变化时调用 (带防抖)
  void onTextChanged(String text) {
    _debounceTimer?.cancel();
    _translateSubscription?.cancel();

    if (text.trim().isEmpty) {
      state = const TranslateEmpty();
      return;
    }

    // 300ms 防抖
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _startTranslation(text);
    });
  }

  /// 立即翻译 (无防抖)
  void translateNow(String text) {
    _debounceTimer?.cancel();
    _translateSubscription?.cancel();

    if (text.trim().isEmpty) {
      state = const TranslateEmpty();
      return;
    }

    _startTranslation(text);
  }

  /// 开始翻译
  Future<void> _startTranslation(String text) async {
    // 先检查缓存
    if (_cache != null) {
      final cached = await _cache.get(text);
      if (cached != null) {
        state = TranslateComplete(cached);
        return;
      }
    }

    // 流式翻译
    state = const TranslateLoading();
    final buffer = StringBuffer();

    _translateSubscription = _aiProvider
        .translate(text: text)
        .listen(
      (result) {
        if (result.isComplete) {
          final finalText = buffer.toString();
          // 缓存结果
          _cache?.set(text, finalText);
          state = TranslateComplete(finalText);
        } else {
          buffer.write(result.text);
          state = TranslateStreaming(buffer.toString());
        }
      },
      onError: (e) {
        state = TranslateError(e.toString());
      },
    );
  }

  /// 清空
  void clear() {
    _debounceTimer?.cancel();
    _translateSubscription?.cancel();
    state = const TranslateEmpty();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _translateSubscription?.cancel();
    super.dispose();
  }
}

/// 翻译控制器 Provider
final translateControllerProvider =
    StateNotifierProvider<TranslateController, TranslateState>((ref) {
  final aiProvider = ref.watch(aiProviderProvider);
  final cache = ref.watch(translationCacheProvider);
  return TranslateController(aiProvider, cache);
});

/// 辅助内容控制器
class AuxiliaryController extends StateNotifier<AuxiliaryState> {
  final AIProvider _aiProvider;
  StreamSubscription? _examplesSubscription;
  StreamSubscription? _quotesSubscription;
  StreamSubscription? _examSubscription;

  AuxiliaryController(this._aiProvider) : super(const AuxiliaryState());

  /// 加载辅助内容
  void loadContent(String word) {
    if (word.trim().isEmpty) {
      state = const AuxiliaryState();
      return;
    }

    _cancelSubscriptions();
    state = const AuxiliaryState(isLoading: true);

    // 加载场景例句
    _examplesSubscription = _aiProvider.getExamples(word).listen(
      (examples) {
        state = state.copyWith(examples: examples);
      },
    );

    // 加载电影台词
    _quotesSubscription = _aiProvider.getMovieQuotes(word).listen(
      (quotes) {
        state = state.copyWith(movieQuotes: quotes);
      },
    );

    // 加载考试真题
    _examSubscription = _aiProvider.getExamItems(word).listen(
      (items) {
        state = state.copyWith(examItems: items, isLoading: false);
      },
    );
  }

  void _cancelSubscriptions() {
    _examplesSubscription?.cancel();
    _quotesSubscription?.cancel();
    _examSubscription?.cancel();
  }

  /// 清空
  void clear() {
    _cancelSubscriptions();
    state = const AuxiliaryState();
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    super.dispose();
  }
}

/// 辅助内容控制器 Provider
final auxiliaryControllerProvider =
    StateNotifierProvider<AuxiliaryController, AuxiliaryState>((ref) {
  final aiProvider = ref.watch(aiProviderProvider);
  return AuxiliaryController(aiProvider);
});

/// 当前输入文本
final inputTextProvider = StateProvider<String>((ref) => '');
