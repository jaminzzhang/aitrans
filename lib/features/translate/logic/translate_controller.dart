import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/ai/ai.dart';
import '../../../core/cache/translation_cache.dart';
import '../../../core/config/ai_config.dart';
import '../models/translate_state.dart';

/// 支持的语言
class Language {
  final String code;
  final String name;
  final String nativeName;

  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Language && runtimeType == other.runtimeType && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

/// 预定义语言列表
class Languages {
  Languages._();

  static const auto = Language(code: 'auto', name: 'Auto Detect', nativeName: '自动检测');
  static const chinese = Language(code: 'zh', name: 'Chinese', nativeName: '中文');
  static const english = Language(code: 'en', name: 'English', nativeName: 'English');
  static const japanese = Language(code: 'ja', name: 'Japanese', nativeName: '日本語');
  static const korean = Language(code: 'ko', name: 'Korean', nativeName: '한국어');
  static const french = Language(code: 'fr', name: 'French', nativeName: 'Français');
  static const german = Language(code: 'de', name: 'German', nativeName: 'Deutsch');
  static const spanish = Language(code: 'es', name: 'Spanish', nativeName: 'Español');
  static const russian = Language(code: 'ru', name: 'Russian', nativeName: 'Русский');
  static const portuguese = Language(code: 'pt', name: 'Portuguese', nativeName: 'Português');
  static const italian = Language(code: 'it', name: 'Italian', nativeName: 'Italiano');

  /// 源语言列表（支持自动检测）
  static const sourceLanguages = [
    auto,
    chinese,
    english,
    japanese,
    korean,
    french,
    german,
    spanish,
    russian,
    portuguese,
    italian,
  ];

  /// 目标语言列表（不支持自动检测）
  static const targetLanguages = [
    chinese,
    english,
    japanese,
    korean,
    french,
    german,
    spanish,
    russian,
    portuguese,
    italian,
  ];
}

/// 源语言 Provider
final sourceLanguageProvider = StateProvider<Language>((ref) {
  return Languages.auto;
});

/// 目标语言 Provider
final targetLanguageProvider = StateProvider<Language>((ref) {
  return Languages.chinese;
});

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
  final String _fromLang;
  final String _toLang;
  Timer? _debounceTimer;
  StreamSubscription? _translateSubscription;

  TranslateController(this._aiProvider, this._cache, this._fromLang, this._toLang)
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
      final cacheKey = "$text-$_toLang"; 
    if ( _cache != null) {
      final cached = await _cache.get(cacheKey);
      if (cached != null) {
        state = TranslateComplete(cached);
        return;
      }
    }

    // 流式翻译
     state = const TranslateLoading();
    final buffer = StringBuffer();

    _translateSubscription = _aiProvider
        .translate(text: text, from: _fromLang, to: _toLang)
        .listen(
      (result) {
        if (result.isComplete) {
          final finalText = buffer.toString();
          // 缓存结果
          _cache?.set(cacheKey, finalText);
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
  final fromLang = ref.watch(sourceLanguageProvider).code;
  final toLang = ref.watch(targetLanguageProvider).code;
  return TranslateController(aiProvider, cache, fromLang, toLang);
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
