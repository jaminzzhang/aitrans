import 'dart:async';

import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/cache/translation_cache.dart';
import 'package:aitrans/core/config/ai_config.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:aitrans/features/translate/models/translate_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('invalid provider config does not break the provider graph', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(aiConfigProvider.notifier).state = AIConfig(
      providerType: ProviderType.qwen,
    );

    final provider = container.read(aiProviderProvider);
    await expectLater(
      provider.translate(text: 'hello'),
      emitsError(isA<AIProviderException>()),
    );
  });

  test(
    'an older cache lookup cannot overwrite the latest translation',
    () async {
      final cache = _DelayedCache();
      final controller = TranslateController(_FakeProvider(), cache);
      addTearDown(controller.dispose);

      controller.translateNow('first');
      controller.translateNow('second');

      cache.completeLookupAt(1, null);
      await pumpEventQueue();
      expect(controller.state, isA<TranslateComplete>());
      expect((controller.state as TranslateComplete).text, 'fresh:second');

      cache.completeLookupAt(0, 'stale:first');
      await pumpEventQueue();
      expect(controller.state, isA<TranslateComplete>());
      expect((controller.state as TranslateComplete).text, 'fresh:second');
    },
  );

  test(
    'an older stream event cannot overwrite the latest translation',
    () async {
      final provider = _ControlledProvider();
      final controller = TranslateController(provider, null);
      addTearDown(controller.dispose);

      controller.translateNow('first');
      controller.translateNow('second');
      provider.emit('second', 'latest');
      await pumpEventQueue();
      expect(controller.state, isA<TranslateStreaming>());
      expect((controller.state as TranslateStreaming).text, 'latest');

      provider.emit('first', 'stale');
      await pumpEventQueue();
      expect(controller.state, isA<TranslateStreaming>());
      expect((controller.state as TranslateStreaming).text, 'latest');
    },
  );

  test('forwards the selected language pair to the AI provider', () async {
    final provider = _LanguageRecordingProvider();
    final controller = TranslateController(
      provider,
      null,
      fromLanguage: 'en',
      toLanguage: 'ja',
    );
    addTearDown(controller.dispose);

    controller.translateNow('hello');
    await pumpEventQueue();

    expect(provider.lastFrom, 'en');
    expect(provider.lastTo, 'ja');
  });

  test('requests enrichment only after the translation completes', () async {
    final provider = _CompletableProvider();
    final enrichedTexts = <String>[];
    final controller = TranslateController(
      provider,
      null,
      onTranslationCompleted: enrichedTexts.add,
    );
    addTearDown(controller.dispose);

    controller.translateNow('hello');
    provider.emitText('translated');
    await pumpEventQueue();
    expect(enrichedTexts, isEmpty);

    provider.complete();
    await pumpEventQueue();
    expect(enrichedTexts, ['hello']);
  });

  test(
    'uses a valid corrected source for enrichment after completion',
    () async {
      final provider = _CompletableProvider();
      final enrichedTexts = <String>[];
      final controller = TranslateController(
        provider,
        null,
        onTranslationCompleted: enrichedTexts.add,
      );
      addTearDown(controller.dispose);

      controller.translateNow('teh cat');
      provider.emitText('CORRECTION: the cat\n猫');
      provider.complete();
      await pumpEventQueue();

      expect(controller.state, isA<TranslateComplete>());
      final complete = controller.state as TranslateComplete;
      expect(complete.sourceText, 'teh cat');
      expect(enrichedTexts, ['the cat']);
    },
  );

  test('uses the corrected source from a cached translation', () async {
    final enrichedTexts = <String>[];
    final controller = TranslateController(
      _FakeProvider(),
      _ImmediateCache('CORRECTION: the cat\n猫'),
      onTranslationCompleted: enrichedTexts.add,
    );
    addTearDown(controller.dispose);

    controller.translateNow('teh cat');
    await pumpEventQueue();

    expect(controller.state, isA<TranslateComplete>());
    expect((controller.state as TranslateComplete).sourceText, 'teh cat');
    expect(enrichedTexts, ['the cat']);
  });

  test('a cache write failure preserves the completed translation', () async {
    final provider = _CompletableProvider();
    final controller = TranslateController(provider, _WriteFailingCache());
    addTearDown(controller.dispose);

    controller.translateNow('hello');
    await pumpEventQueue();
    provider.emitText('你好');
    provider.complete();
    await pumpEventQueue();

    expect(controller.state, isA<TranslateComplete>());
    expect((controller.state as TranslateComplete).text, '你好');
  });

  test('a response without a translation enters the error state', () async {
    final provider = _CompletableProvider();
    final enrichedTexts = <String>[];
    final controller = TranslateController(
      provider,
      null,
      onTranslationCompleted: enrichedTexts.add,
    );
    addTearDown(controller.dispose);

    controller.translateNow('teh cat');
    provider.emitText('CORRECTION: the cat');
    provider.complete();
    await pumpEventQueue();

    expect(controller.state, isA<TranslateError>());
    expect(enrichedTexts, isEmpty);
  });

  group('AuxiliaryController', () {
    test('a failed enrichment request still clears isLoading', () async {
      final controller = AuxiliaryController(_AllAuxFailingProvider());
      addTearDown(controller.dispose);

      expect(controller.state.isLoading, isFalse);
      controller.loadContent('serendipity');
      // 流未处理前应进入加载态。
      expect(controller.state.isLoading, isTrue);

      // 让 error 事件落地。未处理异常不应冒泡出测试（否则 expectLater 抛出）。
      await pumpEventQueue();

      // 关键断言：全部失败后 loading 必须归位，UI 不会被冻结。
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.examples, isEmpty);
      expect(controller.state.movieQuotes, isEmpty);
      expect(controller.state.examItems, isEmpty);
    });

    test('one enrichment response populates all three sections', () async {
      final provider = _CombinedAuxProvider();
      final controller = AuxiliaryController(provider);
      addTearDown(controller.dispose);

      controller.loadContent('hello');
      await pumpEventQueue();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.examples, hasLength(1));
      expect(controller.state.movieQuotes, hasLength(1));
      expect(controller.state.examItems, hasLength(1));
      expect(provider.requestCount, 1);
    });
  });
}

class _CombinedAuxProvider extends _FakeProvider {
  int requestCount = 0;

  @override
  Stream<TranslationEnrichment> enrichTranslation(String text) {
    requestCount++;
    return Stream.value(
      TranslationEnrichment(
        examples: [Example(scene: '日常', original: text, translation: '释义')],
        movieQuotes: [MovieQuote(movie: '电影', quote: text, translation: '释义')],
        examItems: [ExamItem(source: 'CET-6', question: 'Q?', answer: 'A')],
      ),
    );
  }
}

class _FakeProvider extends AIProvider {
  @override
  String get name => 'Fake';

  @override
  String get cacheNamespace => 'fake|endpoint|model';

  @override
  Future<bool> testConnection() async => true;

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) async* {
    yield TranslationResult(text: 'fresh:$text', isComplete: false);
    yield TranslationResult(text: '', isComplete: true);
  }

  @override
  Stream<List<Example>> getExamples(String word) => const Stream.empty();

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();

  @override
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();
}

class _DelayedCache implements TranslationCacheStore {
  final List<Completer<String?>> _lookups = [];

  @override
  Future<String?> get(String key) {
    final lookup = Completer<String?>();
    _lookups.add(lookup);
    return lookup.future;
  }

  @override
  Future<void> set(String key, String value) async {}

  void completeLookupAt(int index, String? value) =>
      _lookups[index].complete(value);
}

class _ImmediateCache implements TranslationCacheStore {
  _ImmediateCache(this.value);

  final String? value;

  @override
  Future<String?> get(String key) async => value;

  @override
  Future<void> set(String key, String value) async {}
}

class _WriteFailingCache implements TranslationCacheStore {
  @override
  Future<String?> get(String key) async => null;

  @override
  Future<void> set(String key, String value) async {
    throw StateError('synthetic cache write failure');
  }
}

class _ControlledProvider extends AIProvider {
  final Map<String, StreamController<TranslationResult>> _controllers = {};

  @override
  String get name => 'Controlled';

  @override
  Future<bool> testConnection() async => true;

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) {
    return (_controllers[text] ??= StreamController<TranslationResult>())
        .stream;
  }

  void emit(String requestText, String resultText) {
    _controllers[requestText]!.add(
      TranslationResult(text: resultText, isComplete: false),
    );
  }

  @override
  Stream<List<Example>> getExamples(String word) => const Stream.empty();

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();

  @override
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();
}

class _CompletableProvider extends _FakeProvider {
  final _controller = StreamController<TranslationResult>();

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) => _controller.stream;

  void emitText(String text) =>
      _controller.add(TranslationResult(text: text, isComplete: false));

  void complete() =>
      _controller.add(TranslationResult(text: '', isComplete: true));
}

class _LanguageRecordingProvider extends _FakeProvider {
  String? lastFrom;
  String? lastTo;

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) {
    lastFrom = from;
    lastTo = to;
    return super.translate(text: text, from: from, to: to);
  }
}

class _AllAuxFailingProvider extends _FakeProvider {
  @override
  Stream<TranslationEnrichment> enrichTranslation(String text) => Stream.error(
    const AIProviderException(
      code: AIProviderErrorCode.invalidResponse,
      message: 'synthetic',
    ),
  );
}
