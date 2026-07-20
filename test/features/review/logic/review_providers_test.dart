import 'package:aitrans/core/config/ai_config.dart';
import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/logic/review_providers.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test/test.dart';

void main() {
  test('defaults to an explicitly unavailable repository', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final repository = container.read(reviewRepositoryProvider);

    expect(repository.state, ReviewRepositoryState.unavailable);
    await expectLater(
      repository.all,
      throwsA(isA<ReviewRepositoryUnavailableException>()),
    );
  });

  test('review ranking owns a provider instance separate from translation', () {
    final config = AIConfig(providerType: ProviderType.ollama);
    final container = ProviderContainer(
      overrides: [initialAIConfigProvider.overrideWithValue(config)],
    );
    addTearDown(container.dispose);

    final translationProvider = container.read(aiProviderProvider);
    final reviewProvider = container.read(reviewAIProviderProvider(config));

    expect(reviewProvider, isNot(same(translationProvider)));
    expect(reviewProvider.cacheNamespace, translationProvider.cacheNamespace);
    expect(
      container.read(reviewRankerProvider(config)).cacheNamespace,
      reviewProvider.cacheNamespace,
    );
  });

  test(
    'review text owns a provider instance separate from all other calls',
    () {
      final config = AIConfig(providerType: ProviderType.ollama);
      final container = ProviderContainer(
        overrides: [initialAIConfigProvider.overrideWithValue(config)],
      );
      addTearDown(container.dispose);

      final translationProvider = container.read(aiProviderProvider);
      final rankingProvider = container.read(reviewAIProviderProvider(config));
      final textProvider = container.read(reviewTextAIProviderProvider(config));
      final service = container.read(reviewContentServiceProvider);

      expect(textProvider, isNot(same(translationProvider)));
      expect(textProvider, isNot(same(rankingProvider)));
      expect(service.cacheNamespace, textProvider.cacheNamespace);
    },
  );

  test('review image owns a separate provider and defaults unsupported', () {
    final config = AIConfig(providerType: ProviderType.ollama);
    final container = ProviderContainer(
      overrides: [initialAIConfigProvider.overrideWithValue(config)],
    );
    addTearDown(container.dispose);

    final translationProvider = container.read(aiProviderProvider);
    final rankingProvider = container.read(reviewAIProviderProvider(config));
    final textProvider = container.read(reviewTextAIProviderProvider(config));
    final imageProvider = container.read(reviewImageAIProviderProvider(config));
    final imageService = container.read(reviewImageServiceProvider);

    expect(imageProvider, isNot(same(translationProvider)));
    expect(imageProvider, isNot(same(rankingProvider)));
    expect(imageProvider, isNot(same(textProvider)));
    expect(imageService.capability.name, 'unsupported');
  });
}
