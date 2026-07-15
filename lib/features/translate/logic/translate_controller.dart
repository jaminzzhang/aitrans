import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../../core/ai/ai.dart';
import '../../../core/cache/translation_cache.dart';
import '../../../core/config/ai_config.dart';
import '../../../core/config/settings_repository.dart';
import '../models/translation_presentation.dart';
import '../models/translate_state.dart';

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
      identical(this, other) || other is Language && code == other.code;

  @override
  int get hashCode => code.hashCode;
}

class Languages {
  Languages._();

  static const auto = Language(
    code: 'auto',
    name: 'Auto Detect',
    nativeName: '自动检测',
  );
  static const chinese = Language(
    code: 'zh',
    name: 'Chinese',
    nativeName: '中文',
  );
  static const english = Language(
    code: 'en',
    name: 'English',
    nativeName: 'English',
  );
  static const japanese = Language(
    code: 'ja',
    name: 'Japanese',
    nativeName: '日本語',
  );
  static const korean = Language(code: 'ko', name: 'Korean', nativeName: '한국어');
  static const french = Language(
    code: 'fr',
    name: 'French',
    nativeName: 'Français',
  );
  static const german = Language(
    code: 'de',
    name: 'German',
    nativeName: 'Deutsch',
  );
  static const spanish = Language(
    code: 'es',
    name: 'Spanish',
    nativeName: 'Español',
  );
  static const russian = Language(
    code: 'ru',
    name: 'Russian',
    nativeName: 'Русский',
  );
  static const portuguese = Language(
    code: 'pt',
    name: 'Portuguese',
    nativeName: 'Português',
  );
  static const italian = Language(
    code: 'it',
    name: 'Italian',
    nativeName: 'Italiano',
  );

  static const source = [
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

  static const target = [
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

final sourceLanguageProvider = StateProvider<Language>((ref) => Languages.auto);
final targetLanguageProvider = StateProvider<Language>(
  (ref) => Languages.chinese,
);

/// AI 配置 Provider
final initialAIConfigProvider = Provider<AIConfig>((ref) {
  return AIConfig(providerType: ProviderType.ollama);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return const UnavailableSettingsRepository();
});

final initialSettingsStorageErrorProvider = Provider<String?>((ref) => null);

final settingsStorageErrorProvider = StateProvider<String?>((ref) {
  return ref.watch(initialSettingsStorageErrorProvider);
});

final aiConfigProvider = StateProvider<AIConfig>((ref) {
  return ref.watch(initialAIConfigProvider);
});

/// AI Provider 实例
final aiProviderProvider = Provider<AIProvider>((ref) {
  final config = ref.watch(aiConfigProvider);
  late final AIProvider provider;
  try {
    provider = ProviderFactory.create(config);
  } on AIConfigurationException catch (error) {
    provider = _UnavailableAIProvider(
      ProviderFactory.providerName(config.providerType),
      error.message,
    );
  }
  ref.onDispose(provider.close);
  return provider;
});

class _UnavailableAIProvider extends AIProvider {
  _UnavailableAIProvider(this.name, this._message);

  @override
  final String name;

  final String _message;

  AIProviderException get _error => AIProviderException(
    code: AIProviderErrorCode.invalidConfiguration,
    message: _message,
  );

  @override
  Future<bool> testConnection() async => false;

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) => Stream.error(_error);

  @override
  Stream<List<Example>> getExamples(String word) => const Stream.empty();

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();

  @override
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();
}

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
  final TranslationCacheStore? _cache;
  final String _fromLanguage;
  final String _toLanguage;
  final ValueChanged<String>? _onTranslationCompleted;
  Timer? _debounceTimer;
  StreamSubscription? _translateSubscription;
  int _requestGeneration = 0;

  TranslateController(
    this._aiProvider,
    this._cache, {
    String fromLanguage = 'auto',
    String toLanguage = 'zh',
    ValueChanged<String>? onTranslationCompleted,
  }) : _fromLanguage = fromLanguage,
       _toLanguage = toLanguage,
       _onTranslationCompleted = onTranslationCompleted,
       super(const TranslateEmpty());

  /// 输入变化时调用 (带防抖)
  void onTextChanged(String text) {
    final generation = ++_requestGeneration;
    _debounceTimer?.cancel();
    _translateSubscription?.cancel();
    _aiProvider.cancelActiveRequests();

    if (text.trim().isEmpty) {
      state = const TranslateEmpty();
      return;
    }

    // 300ms 防抖
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _startTranslation(text, generation, enrichAfterCompletion: false);
    });
  }

  /// 立即翻译 (无防抖)
  void translateNow(String text) {
    final generation = ++_requestGeneration;
    _debounceTimer?.cancel();
    _translateSubscription?.cancel();
    _aiProvider.cancelActiveRequests();

    if (text.trim().isEmpty) {
      state = const TranslateEmpty();
      return;
    }

    _startTranslation(text, generation, enrichAfterCompletion: true);
  }

  /// 开始翻译
  Future<void> _startTranslation(
    String text,
    int generation, {
    required bool enrichAfterCompletion,
  }) async {
    final cacheKey = TranslationCacheIdentity(
      providerNamespace: _aiProvider.cacheNamespace,
      text: text,
      from: _fromLanguage,
      to: _toLanguage,
      options: const {
        'outputContract': TranslationPresentation.outputContractVersion,
      },
    ).key;
    // 先检查缓存
    if (_cache != null) {
      final cached = await _cache.get(cacheKey);
      if (generation != _requestGeneration) return;
      if (cached != null) {
        state = TranslateComplete(cached);
        if (enrichAfterCompletion) {
          _onTranslationCompleted?.call(text);
        }
        return;
      }
    }

    // 流式翻译
    state = const TranslateLoading();
    final buffer = StringBuffer();
    var didComplete = false;

    _translateSubscription = _aiProvider
        .translate(text: text, from: _fromLanguage, to: _toLanguage)
        .listen(
          (result) {
            if (generation != _requestGeneration) return;
            if (result.isComplete) {
              if (didComplete) return;
              didComplete = true;
              final finalText = buffer.toString();
              // 缓存结果
              _cache?.set(cacheKey, finalText);
              state = TranslateComplete(finalText);
              if (enrichAfterCompletion) {
                _onTranslationCompleted?.call(text);
              }
            } else {
              buffer.write(result.text);
              state = TranslateStreaming(buffer.toString());
            }
          },
          onError: (e) {
            if (generation != _requestGeneration) return;
            state = TranslateError(e.toString());
          },
        );
  }

  /// 清空
  void clear() {
    _requestGeneration++;
    _debounceTimer?.cancel();
    _translateSubscription?.cancel();
    _aiProvider.cancelActiveRequests();
    state = const TranslateEmpty();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _translateSubscription?.cancel();
    _aiProvider.cancelActiveRequests();
    super.dispose();
  }
}

/// 翻译控制器 Provider
final translateControllerProvider =
    StateNotifierProvider<TranslateController, TranslateState>((ref) {
      final aiProvider = ref.watch(aiProviderProvider);
      final cache = ref.watch(translationCacheProvider);
      final sourceLanguage = ref.watch(sourceLanguageProvider);
      final targetLanguage = ref.watch(targetLanguageProvider);
      return TranslateController(
        aiProvider,
        cache,
        fromLanguage: sourceLanguage.code,
        toLanguage: targetLanguage.code,
        onTranslationCompleted: (text) {
          ref.read(auxiliaryControllerProvider.notifier).loadContent(text);
        },
      );
    });

/// 辅助内容控制器
class AuxiliaryController extends StateNotifier<AuxiliaryState> {
  final AIProvider _aiProvider;
  StreamSubscription<TranslationEnrichment>? _enrichmentSubscription;

  AuxiliaryController(this._aiProvider) : super(const AuxiliaryState());

  /// 用一次 AI 请求加载全部扩展内容。
  void loadContent(String word) {
    if (word.trim().isEmpty) {
      state = const AuxiliaryState();
      return;
    }

    _enrichmentSubscription?.cancel();
    state = const AuxiliaryState(isLoading: true);

    _enrichmentSubscription = _aiProvider
        .enrichTranslation(word)
        .listen(
          (enrichment) {
            state = AuxiliaryState(
              examples: enrichment.examples,
              movieQuotes: enrichment.movieQuotes,
              examItems: enrichment.examItems,
              isLoading: true,
            );
          },
          onError: (_) {
            debugPrint('Translation enrichment failed.');
            if (mounted) state = state.copyWith(isLoading: false);
          },
          onDone: () {
            if (mounted) state = state.copyWith(isLoading: false);
          },
        );
  }

  /// 清空
  void clear() {
    _enrichmentSubscription?.cancel();
    state = const AuxiliaryState();
  }

  @override
  void dispose() {
    _enrichmentSubscription?.cancel();
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
