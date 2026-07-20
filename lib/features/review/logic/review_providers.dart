import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/provider_factory.dart';
import '../../../core/ai/review_ai_models.dart';
import '../../../core/config/ai_config.dart';
import '../../translate/logic/translate_controller.dart';
import '../data/review_repository.dart';
import '../data/review_preferences_store.dart';
import '../domain/review_scheduler.dart';
import '../services/review_content_service.dart';
import '../services/review_image_service.dart';
import '../services/review_ranker.dart';
import 'review_capture_service.dart';
import 'review_history_controller.dart';
import 'review_queue_controller.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => const UnavailableReviewRepository(),
);

final initialReviewPreferencesProvider = Provider<ReviewPreferences>((ref) {
  return ReviewPreferences.defaults;
});

final reviewPreferencesStoreProvider = Provider<ReviewPreferencesStore>((ref) {
  return MemoryReviewPreferencesStore(
    ref.watch(initialReviewPreferencesProvider),
  );
});

final reviewCaptureEnabledProvider = StateProvider<bool>((ref) {
  return ref.watch(initialReviewPreferencesProvider).captureEnabled;
});

final reviewCaptureResultProvider = StateProvider<ReviewCaptureResult?>(
  (ref) => null,
);

final reviewCaptureProvider = Provider<ReviewCapture>((ref) {
  final repository = ref.watch(reviewRepositoryProvider);
  return ReviewCaptureService(
    repository: repository,
    isCaptureEnabled: () => ref.read(reviewCaptureEnabledProvider),
    now: DateTime.now,
  );
});

final reviewSchedulerProvider = Provider<ReviewScheduler>((ref) {
  return ReviewScheduler(now: DateTime.now);
});

final reviewQueueControllerProvider = Provider<ReviewQueueController>((ref) {
  final config = ref.watch(aiConfigProvider);
  final controller = ReviewQueueController(
    repository: ref.watch(reviewRepositoryProvider),
    scheduler: ref.watch(reviewSchedulerProvider),
    ranker: ref.watch(reviewRankerProvider(config)),
    now: DateTime.now,
  );
  ref.onDispose(() {
    controller.invalidate();
  });
  return controller;
});

final reviewHistoryControllerProvider =
    StateNotifierProvider<ReviewHistoryController, ReviewHistoryState>((ref) {
      final controller = ReviewHistoryController(
        repository: ref.watch(reviewRepositoryProvider),
        scheduler: ref.watch(reviewSchedulerProvider),
        queueController: ref.watch(reviewQueueControllerProvider),
        contentService: ref.watch(reviewContentServiceProvider),
        imageService: ref.watch(reviewImageServiceProvider),
        preferencesStore: ref.watch(reviewPreferencesStoreProvider),
        onCaptureEnabledChanged: (enabled) {
          ref.read(reviewCaptureEnabledProvider.notifier).state = enabled;
        },
      );
      ref.listen<ReviewCaptureResult?>(reviewCaptureResultProvider, (
        previous,
        next,
      ) {
        if (next?.status == ReviewCaptureStatus.captured) {
          ref.read(reviewQueueControllerProvider).invalidate();
          controller.reload();
        }
      });
      return controller;
    });

final reviewAIProviderProvider = Provider.autoDispose
    .family<AIProvider, AIConfig>((ref, config) {
      late final AIProvider provider;
      try {
        provider = ProviderFactory.create(config);
      } on AIConfigurationException catch (error) {
        provider = _UnavailableReviewAIProvider(
          name: ProviderFactory.providerName(config.providerType),
          message: error.message,
        );
      }
      ref.onDispose(provider.close);
      return provider;
    });

final reviewRankerProvider = Provider.autoDispose
    .family<ReviewRanker, AIConfig>((ref, config) {
      return AIReviewRanker(
        provider: ref.watch(reviewAIProviderProvider(config)),
      );
    });

final reviewTextAIProviderProvider = Provider.autoDispose
    .family<AIProvider, AIConfig>((ref, config) {
      late final AIProvider provider;
      try {
        provider = ProviderFactory.create(config);
      } on AIConfigurationException catch (error) {
        provider = _UnavailableReviewAIProvider(
          name: ProviderFactory.providerName(config.providerType),
          message: error.message,
        );
      }
      ref.onDispose(provider.close);
      return provider;
    });

final reviewTextContentGeneratorProvider = Provider.autoDispose
    .family<ReviewTextContentGenerator, AIConfig>((ref, config) {
      return AIReviewTextContentGenerator(
        provider: ref.watch(reviewTextAIProviderProvider(config)),
      );
    });

final reviewContentServiceProvider = Provider<ReviewContentService>((ref) {
  final config = ref.watch(aiConfigProvider);
  final service = ReviewContentService(
    repository: ref.watch(reviewRepositoryProvider),
    generator: ref.watch(reviewTextContentGeneratorProvider(config)),
    now: DateTime.now,
  );
  ref.onDispose(service.invalidate);
  return service;
});

final reviewImageAIProviderProvider = Provider.autoDispose
    .family<AIProvider, AIConfig>((ref, config) {
      late final AIProvider provider;
      try {
        provider = ProviderFactory.create(config);
      } on AIConfigurationException catch (error) {
        provider = _UnavailableReviewAIProvider(
          name: ProviderFactory.providerName(config.providerType),
          message: error.message,
        );
      }
      ref.onDispose(provider.close);
      return provider;
    });

final reviewImageGeneratorProvider = Provider.autoDispose
    .family<ReviewImageGenerator, AIConfig>((ref, config) {
      return AIReviewImageGenerator(
        provider: ref.watch(reviewImageAIProviderProvider(config)),
      );
    });

final reviewImageServiceProvider = Provider<ReviewImageService>((ref) {
  final config = ref.watch(aiConfigProvider);
  final service = ReviewImageService(
    repository: ref.watch(reviewRepositoryProvider),
    generator: ref.watch(reviewImageGeneratorProvider(config)),
    now: DateTime.now,
  );
  ref.onDispose(service.invalidate);
  return service;
});

class _UnavailableReviewAIProvider extends AIProvider {
  _UnavailableReviewAIProvider({required this.name, required String message})
    : _message = message;

  @override
  final String name;

  final String _message;

  @override
  Future<ReviewAIRankResponse> rankReviewCandidates(
    ReviewAIRankRequest request,
  ) => Future.error(
    AIProviderException(
      code: AIProviderErrorCode.invalidConfiguration,
      message: _message,
    ),
  );

  @override
  Future<bool> testConnection() async => false;

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) => Stream.error(
    AIProviderException(
      code: AIProviderErrorCode.invalidConfiguration,
      message: _message,
    ),
  );

  @override
  Stream<List<Example>> getExamples(String word) => const Stream.empty();

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();

  @override
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();
}
