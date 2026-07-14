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
