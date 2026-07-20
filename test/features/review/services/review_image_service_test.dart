import 'dart:async';

import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/review/services/review_image_service.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DateTime now;
  late ReviewEntry entry;
  late _MemoryRepository repository;

  setUp(() {
    now = DateTime.utc(2026, 7, 20, 12);
    entry = _entry();
    repository = _MemoryRepository([entry]);
  });

  test(
    'unsupported capability uses fallback without calling or caching',
    () async {
      final generator = _Generator(
        capability: ReviewAIImageCapability.unsupported,
      );
      final service = ReviewImageService(
        repository: repository,
        generator: generator,
        now: () => now,
      );

      final result = await service.load(entry);

      expect(result.status, ReviewImageLoadStatus.fallback);
      expect(result.failure, ReviewImageFailure.unsupported);
      expect(generator.requests, isEmpty);
      expect(repository.derived, isEmpty);
    },
  );

  test(
    'supported capability generates once then reads encrypted cache',
    () async {
      final generator = _Generator();
      final firstService = ReviewImageService(
        repository: repository,
        generator: generator,
        now: () => now,
      );

      final first = await firstService.load(entry);
      final cached = await ReviewImageService(
        repository: repository,
        generator: generator,
        now: () => now,
      ).load(entry);

      expect(first.status, ReviewImageLoadStatus.ready);
      expect(first.source, ReviewImageSource.ai);
      expect(first.image?.mediaType, 'image/png');
      expect(cached.status, ReviewImageLoadStatus.ready);
      expect(cached.source, ReviewImageSource.cache);
      expect(generator.requests, hasLength(1));
      expect(generator.requests.single.toJson().keys, {
        'contractVersion',
        'term',
        'sourceLanguage',
        'targetLanguage',
        'primaryMeaning',
      });
    },
  );

  test(
    'failure is not automatically retried but manual image retry is',
    () async {
      final generator = _Generator(failuresBeforeSuccess: 1);
      final service = ReviewImageService(
        repository: repository,
        generator: generator,
        now: () => now,
      );

      final failed = await service.load(entry);
      final stillFailed = await service.load(entry);
      final retried = await service.load(entry, manualRetry: true);

      expect(failed.status, ReviewImageLoadStatus.fallback);
      expect(failed.failure, ReviewImageFailure.safetyRejected);
      expect(stillFailed.status, ReviewImageLoadStatus.fallback);
      expect(retried.status, ReviewImageLoadStatus.ready);
      expect(generator.requests, hasLength(2));
    },
  );

  test('provider namespace isolates image cache', () async {
    final first = _Generator(namespace: 'provider-a|model-a');
    final second = _Generator(namespace: 'provider-a|model-b');

    await ReviewImageService(
      repository: repository,
      generator: first,
      now: () => now,
    ).load(entry);
    await ReviewImageService(
      repository: repository,
      generator: second,
      now: () => now,
    ).load(entry);

    expect(first.requests, hasLength(1));
    expect(second.requests, hasLength(1));
    expect(repository.derived, hasLength(2));
  });

  test('AI image timeout cancels its dedicated provider request', () async {
    final provider = _ImageAIProvider(neverCompletes: true);
    final generator = AIReviewImageGenerator(
      provider: provider,
      timeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      generator.generate(_request()),
      throwsA(
        isA<ReviewImageException>().having(
          (error) => error.failure,
          'failure',
          ReviewImageFailure.timeout,
        ),
      ),
    );
    expect(provider.cancelCount, 1);
  });

  test('AI image safety refusal stays a typed sanitized failure', () async {
    final generator = AIReviewImageGenerator(
      provider: _ImageAIProvider(safetyRejected: true),
    );

    await expectLater(
      generator.generate(_request()),
      throwsA(
        isA<ReviewImageException>().having(
          (error) => error.failure,
          'failure',
          ReviewImageFailure.safetyRejected,
        ),
      ),
    );
  });

  test(
    'deletion while generation is in flight discards the late image',
    () async {
      final generator = _Generator(controlled: true);
      final service = ReviewImageService(
        repository: repository,
        generator: generator,
        now: () => now,
      );
      final pending = service.load(entry);
      await Future<void>.delayed(Duration.zero);

      await repository.delete(entry.identity);
      generator.complete();

      expect((await pending).status, ReviewImageLoadStatus.discarded);
      expect(repository.derived, isEmpty);
    },
  );

  test('invalidation discards a late result and cancels the request', () async {
    final generator = _Generator(controlled: true);
    final service = ReviewImageService(
      repository: repository,
      generator: generator,
      now: () => now,
    );
    final pending = service.load(entry);
    await Future<void>.delayed(Duration.zero);

    await service.invalidate();
    generator.complete();

    expect((await pending).status, ReviewImageLoadStatus.discarded);
    expect(generator.cancelCount, 1);
    expect(repository.derived, isEmpty);
  });
}

ReviewAIImageRequest _request() => ReviewAIImageRequest(
  term: 'break the ice',
  sourceLanguage: 'en',
  targetLanguage: 'zh',
  primaryMeaning: '打破僵局',
);

class _ImageAIProvider extends AIProvider {
  _ImageAIProvider({this.neverCompletes = false, this.safetyRejected = false});

  final bool neverCompletes;
  final bool safetyRejected;
  int cancelCount = 0;

  @override
  String get name => 'image-ai-test';

  @override
  ReviewAIImageCapability get reviewImageCapability =>
      ReviewAIImageCapability.supported;

  @override
  Future<ReviewAIImageResponse> generateReviewImage(
    ReviewAIImageRequest request,
  ) {
    if (neverCompletes) return Completer<ReviewAIImageResponse>().future;
    if (safetyRejected) {
      return Future.error(
        const AIProviderException(
          code: AIProviderErrorCode.safetyRejected,
          message: 'sanitized safety refusal',
        ),
      );
    }
    return Future.value(_response());
  }

  @override
  Future<void> cancelActiveRequests() async => cancelCount++;

  @override
  Future<bool> testConnection() async => true;

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) => const Stream.empty();

  @override
  Stream<List<Example>> getExamples(String word) => const Stream.empty();

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();

  @override
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();
}

class _Generator implements ReviewImageGenerator {
  _Generator({
    this.capability = ReviewAIImageCapability.supported,
    this.namespace = 'image-provider|model-1',
    this.failuresBeforeSuccess = 0,
    this.controlled = false,
  });

  @override
  final ReviewAIImageCapability capability;
  final String namespace;
  final int failuresBeforeSuccess;
  final bool controlled;
  final requests = <ReviewAIImageRequest>[];
  final _completers = <Completer<ReviewAIImageResponse>>[];
  int cancelCount = 0;

  @override
  String get cacheNamespace => namespace;

  @override
  Future<void> cancelActiveRequest() async => cancelCount++;

  @override
  Future<ReviewAIImageResponse> generate(ReviewAIImageRequest request) async {
    requests.add(request);
    if (requests.length <= failuresBeforeSuccess) {
      throw const ReviewImageException(ReviewImageFailure.safetyRejected);
    }
    if (controlled) {
      final completer = Completer<ReviewAIImageResponse>();
      _completers.add(completer);
      return completer.future;
    }
    return _response();
  }

  void complete() => _completers.single.complete(_response());
}

ReviewAIImageResponse _response() => ReviewAIImageResponse(
  mediaType: 'image/png',
  bytes: const [137, 80, 78, 71, 13, 10, 26, 10],
);

class _MemoryRepository implements ReviewRepository {
  _MemoryRepository(Iterable<ReviewEntry> entries)
    : entries = {for (final entry in entries) entry.identity: entry};

  final Map<ReviewIdentity, ReviewEntry> entries;
  final Map<String, ReviewDerivedContent> derived = {};

  String _key(ReviewIdentity identity, String contentId) =>
      '${identity.toJson()}|$contentId';

  @override
  ReviewRepositoryState get state => ReviewRepositoryState.ready;

  @override
  Future<ReviewEntry?> applyFeedback({
    required ReviewIdentity identity,
    required ReviewFeedbackEvent event,
    required ReviewScheduler scheduler,
  }) => throw UnsupportedError('not used');

  @override
  Future<List<ReviewEntry>> all() async => List.unmodifiable(entries.values);

  @override
  Future<void> clearAndReset() async {
    entries.clear();
    derived.clear();
  }

  @override
  Future<void> delete(ReviewIdentity identity) async {
    entries.remove(identity);
    derived.removeWhere((_, value) => value.identity == identity);
  }

  @override
  Future<ReviewEntry?> find(ReviewIdentity identity) async => entries[identity];

  @override
  Future<ReviewDerivedContent?> findDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required DateTime accessedAt,
  }) async => derived[_key(identity, contentId)];

  @override
  Future<bool> putDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required String mediaType,
    required List<int> bytes,
    required int expectedGeneration,
    required DateTime accessedAt,
  }) async {
    final entry = entries[identity];
    if (entry == null || entry.generation != expectedGeneration) return false;
    derived[_key(identity, contentId)] = ReviewDerivedContent(
      identity: identity,
      contentId: contentId,
      mediaType: mediaType,
      bytes: bytes,
      generation: expectedGeneration,
      lastAccessedAt: accessedAt,
    );
    return true;
  }

  @override
  Future<ReviewEntry> recordTranslation({
    required ReviewIdentity identity,
    required String originalAlias,
    required DateTime translatedAt,
    required ReviewEntryContent content,
  }) => throw UnsupportedError('not used');
}

ReviewEntry _entry() {
  final identity = ReviewIdentity.create(
    correctedTerm: 'break the ice',
    actualSourceLanguage: TranslationSourceLanguage.en,
    targetLanguage: TranslationSourceLanguage.zh,
  );
  return ReviewEntry.firstTranslation(
    identity: identity,
    originalAlias: 'break the ice',
    translatedAt: DateTime.utc(2026, 7, 18),
    content: ReviewEntryContent(
      sourceText: 'break the ice',
      translationText: '打破僵局',
      primaryMeaning: '打破僵局',
      secondaryMeanings: const [],
    ),
  );
}
