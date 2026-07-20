import 'dart:async';
import 'dart:convert';

import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:aitrans/features/review/data/encrypted_review_repository.dart';
import 'package:aitrans/features/review/data/review_key_store.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/review/services/review_content_service.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:cryptography/cryptography.dart';
import 'package:test/test.dart';

void main() {
  test(
    'generates once with minimal fields then uses encrypted content cache',
    () async {
      final repository = _MemoryRepository([_entry()]);
      final generator = _FakeGenerator();
      final service = ReviewContentService(
        repository: repository,
        generator: generator,
        now: () => DateTime.utc(2026, 7, 20, 8),
      );

      final first = await service.load(_entry());
      final second = await service.load(_entry());

      expect(first.status, ReviewContentLoadStatus.ready);
      expect(first.source, ReviewContentSource.ai);
      expect(second.status, ReviewContentLoadStatus.ready);
      expect(second.source, ReviewContentSource.cache);
      expect(generator.callCount, 1);
      expect(generator.lastRequest!.toJson(), {
        'contractVersion': 1,
        'term': 'break the ice',
        'sourceLanguage': 'en',
        'targetLanguage': 'zh',
        'primaryMeaning': '打破僵局',
      });
      expect(repository.derivedValues, hasLength(1));
      expect(
        repository.derivedValues.single.mediaType,
        contains('review-text'),
      );
      expect(
        repository.derivedValues.single.contentId,
        isNot(contains('break the ice')),
      );
    },
  );

  test(
    'persists a failed attempt and only retries after an explicit action',
    () async {
      final repository = _MemoryRepository([_entry()]);
      final generator = _FailingThenSuccessfulGenerator();
      final service = ReviewContentService(
        repository: repository,
        generator: generator,
        now: () => DateTime.utc(2026, 7, 20, 9),
      );

      final failed = await service.load(_entry());
      final automaticReentry = await service.load(_entry());

      expect(failed.status, ReviewContentLoadStatus.degraded);
      expect(automaticReentry.status, ReviewContentLoadStatus.degraded);
      expect(generator.callCount, 1);

      final manualRetry = await service.load(_entry(), manualRetry: true);
      expect(manualRetry.status, ReviewContentLoadStatus.ready);
      expect(generator.callCount, 2);
    },
  );

  test(
    'discards text that arrives after its review entry was deleted',
    () async {
      final entry = _entry();
      final repository = _MemoryRepository([entry]);
      final generator = _DelayedGenerator();
      final service = ReviewContentService(
        repository: repository,
        generator: generator,
        now: () => DateTime.utc(2026, 7, 20, 10),
      );

      final pending = service.load(entry);
      await generator.started.future;
      await repository.delete(entry.identity);
      generator.complete();

      final result = await pending;
      expect(result.status, ReviewContentLoadStatus.discarded);
      expect(repository.derivedValues, isEmpty);
      expect(repository.entries, isEmpty);
    },
  );

  test('times out and cancels only the dedicated text provider', () async {
    final provider = _DelayedAIProvider();
    final generator = AIReviewTextContentGenerator(
      provider: provider,
      timeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      generator.generate(
        ReviewAITextContentRequest(
          term: 'hello',
          sourceLanguage: 'en',
          targetLanguage: 'zh',
          primaryMeaning: '你好',
        ),
      ),
      throwsA(
        isA<ReviewTextContentException>().having(
          (error) => error.failure,
          'failure',
          ReviewTextContentFailure.timeout,
        ),
      ),
    );
    expect(provider.cancelCount, 1);
  });

  test(
    'provider context invalidation discards an uncancellable late result',
    () async {
      final entry = _entry();
      final repository = _MemoryRepository([entry]);
      final generator = _DelayedGenerator();
      final service = ReviewContentService(
        repository: repository,
        generator: generator,
        now: () => DateTime.utc(2026, 7, 20, 11),
      );

      final pending = service.load(entry);
      await generator.started.future;
      await service.invalidate();
      generator.complete();

      expect((await pending).status, ReviewContentLoadStatus.discarded);
      expect(generator.cancelCount, 1);
      expect(repository.derivedValues, isEmpty);
    },
  );

  test(
    'stores generated review text only through encrypted derived content',
    () async {
      final historyStore = _MemoryCiphertextStore();
      final contentStore = _MemoryCiphertextStore();
      final repository = EncryptedReviewRepository(
        historyStore: historyStore,
        contentStore: contentStore,
        keyStore: _MemoryKeyStore(),
      );
      final fixture = _entry();
      final storedEntry = await repository.recordTranslation(
        identity: fixture.identity,
        originalAlias: 'break the ice',
        translatedAt: fixture.latestTranslatedAt,
        content: fixture.latestContent,
      );
      final service = ReviewContentService(
        repository: repository,
        generator: _FakeGenerator(),
        now: () => DateTime.utc(2026, 7, 20, 14),
      );

      expect(
        (await service.load(storedEntry)).status,
        ReviewContentLoadStatus.ready,
      );

      final rawContent = jsonEncode(contentStore.values);
      expect(contentStore.values, hasLength(1));
      expect(rawContent, isNot(contains('初次见面')));
      expect(rawContent, isNot(contains('break the ice')));
      expect(rawContent, isNot(contains('影视化')));
    },
  );
}

class _FakeGenerator implements ReviewTextContentGenerator {
  int callCount = 0;
  int cancelCount = 0;
  ReviewAITextContentRequest? lastRequest;

  @override
  String get cacheNamespace => 'fake-provider|fake-model';

  @override
  Future<void> cancelActiveRequest() async {
    cancelCount++;
  }

  @override
  Future<ReviewAITextContentResponse> generate(
    ReviewAITextContentRequest request,
  ) async {
    callCount++;
    lastRequest = request;
    return ReviewAITextContentResponse(
      everydayUsages: [
        ReviewAIEverydayUsage(
          situation: '初次见面',
          original: 'A simple question helped break the ice.',
          translation: '一个简单的问题帮助大家打破了僵局。',
        ),
      ],
      fictionalDialogue: ReviewAIFictionalDialogue(
        dialogue: 'We should break the ice before the meeting.',
        translation: '开会前我们应该先活跃一下气氛。',
      ),
    );
  }
}

class _FailingThenSuccessfulGenerator extends _FakeGenerator {
  @override
  Future<ReviewAITextContentResponse> generate(
    ReviewAITextContentRequest request,
  ) async {
    if (callCount == 0) {
      callCount++;
      lastRequest = request;
      throw StateError('/private/path user-secret should stay hidden');
    }
    return super.generate(request);
  }
}

class _DelayedGenerator extends _FakeGenerator {
  final started = Completer<void>();
  final _response = Completer<ReviewAITextContentResponse>();

  @override
  Future<ReviewAITextContentResponse> generate(
    ReviewAITextContentRequest request,
  ) {
    callCount++;
    lastRequest = request;
    if (!started.isCompleted) started.complete();
    return _response.future;
  }

  void complete() {
    _response.complete(
      ReviewAITextContentResponse(
        everydayUsages: [
          ReviewAIEverydayUsage(
            situation: '迟到场景',
            original: 'Late generated content.',
            translation: '迟到生成的内容。',
          ),
        ],
        fictionalDialogue: ReviewAIFictionalDialogue(
          dialogue: 'This response arrived too late.',
          translation: '这个响应来得太晚了。',
        ),
      ),
    );
  }
}

class _DelayedAIProvider extends AIProvider {
  int cancelCount = 0;

  @override
  String get name => 'delayed-content-provider';

  @override
  Future<void> cancelActiveRequests() async {
    cancelCount++;
  }

  @override
  Future<ReviewAITextContentResponse> generateReviewTextContent(
    ReviewAITextContentRequest request,
  ) => Completer<ReviewAITextContentResponse>().future;

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
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();
}

class _MemoryRepository implements ReviewRepository {
  _MemoryRepository(Iterable<ReviewEntry> entries)
    : entries = {for (final entry in entries) entry.identity: entry};

  final Map<ReviewIdentity, ReviewEntry> entries;
  final Map<String, ReviewDerivedContent> _derived = {};

  Iterable<ReviewDerivedContent> get derivedValues => _derived.values;

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
    _derived.clear();
  }

  @override
  Future<void> delete(ReviewIdentity identity) async {
    entries.remove(identity);
    _derived.removeWhere((_, value) => value.identity == identity);
  }

  @override
  Future<ReviewEntry?> find(ReviewIdentity identity) async => entries[identity];

  @override
  Future<ReviewDerivedContent?> findDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required DateTime accessedAt,
  }) async => _derived[_key(identity, contentId)];

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
    _derived[_key(identity, contentId)] = ReviewDerivedContent(
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
  }) async => throw UnsupportedError('not used');
}

class _MemoryKeyStore implements ReviewKeyStore {
  SecretKey? _key;

  @override
  Future<SecretKey?> loadExisting() async => _key;

  @override
  Future<SecretKey> create() async {
    return _key ??= SecretKey(List<int>.filled(32, 7));
  }

  @override
  Future<void> delete() async {
    _key = null;
  }
}

class _MemoryCiphertextStore implements ReviewCiphertextStore {
  final Map<String, Object> values = {};

  @override
  bool get isEmpty => values.isEmpty;

  @override
  Iterable<String> get keys => List.unmodifiable(values.keys);

  @override
  Object? read(String key) => values[key];

  @override
  Future<void> write(String key, Object value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<void> clear() async {
    values.clear();
  }
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
      partOfSpeech: 'idiom',
      pronunciation: '/breɪk ði aɪs/',
      secondaryMeanings: const ['活跃气氛'],
    ),
  );
}
