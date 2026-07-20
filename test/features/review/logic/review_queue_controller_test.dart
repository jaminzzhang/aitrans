import 'dart:async';

import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/logic/review_queue_controller.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/review/services/review_ranker.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds a 10-card AI snapshot from at most 50 due candidates', () async {
    final now = DateTime.utc(2026, 7, 20, 8);
    final repository = _MemoryReviewRepository(
      List.generate(
        55,
        (index) => _entry(
          term: 'term-$index',
          createdAt: now.subtract(const Duration(days: 10)),
          nextReviewAt: now.subtract(Duration(hours: index + 1)),
        ),
      ),
    );
    final ranker = _FakeReviewRanker((request) async {
      return ReviewAIRankResponse(
        rankedItems: request.candidates
            .take(10)
            .toList()
            .reversed
            .map(
              (candidate) => ReviewAIRankedItem(
                id: candidate.id,
                reason: 'Needs another look',
              ),
            ),
      );
    });
    final controller = ReviewQueueController(
      repository: repository,
      scheduler: ReviewScheduler(now: () => now),
      ranker: ranker,
      now: () => now,
    );

    final snapshot = await controller.buildGroup();

    expect(ranker.requests, hasLength(1));
    expect(ranker.requests.single.candidates, hasLength(50));
    expect(snapshot.totalDueCount, 55);
    expect(snapshot.candidateCount, 50);
    expect(snapshot.items, hasLength(10));
    expect(snapshot.items.map((item) => item.entry.identity.normalizedTerm), [
      'term-45',
      'term-46',
      'term-47',
      'term-48',
      'term-49',
      'term-50',
      'term-51',
      'term-52',
      'term-53',
      'term-54',
    ]);
    expect(snapshot.source, ReviewQueueSource.ai);
  });

  test('AI failure falls back to the stable local ordering', () async {
    final now = DateTime.utc(2026, 7, 20, 8);
    final sharedDueAt = now.subtract(const Duration(days: 1));
    final repository = _MemoryReviewRepository([
      _entry(
        term: 'beta',
        createdAt: now.subtract(const Duration(days: 10)),
        nextReviewAt: sharedDueAt,
        forgetCount: 2,
      ),
      _entry(
        term: 'alpha',
        createdAt: now.subtract(const Duration(days: 10)),
        nextReviewAt: sharedDueAt,
        forgetCount: 2,
      ),
      _entry(
        term: 'reviewed',
        createdAt: now.subtract(const Duration(days: 10)),
        nextReviewAt: sharedDueAt,
        forgetCount: 3,
        lastReviewedAt: now.subtract(const Duration(days: 5)),
      ),
      _entry(
        term: 'never-reviewed',
        createdAt: now.subtract(const Duration(days: 10)),
        nextReviewAt: sharedDueAt,
        forgetCount: 3,
      ),
      _entry(
        term: 'most-overdue',
        createdAt: now.subtract(const Duration(days: 10)),
        nextReviewAt: now.subtract(const Duration(days: 2)),
      ),
    ]);
    final ranker = _FakeReviewRanker((_) async {
      throw StateError('synthetic AI failure');
    });
    final controller = ReviewQueueController(
      repository: repository,
      scheduler: ReviewScheduler(now: () => now),
      ranker: ranker,
      now: () => now,
    );

    final snapshot = await controller.buildGroup();

    expect(snapshot.source, ReviewQueueSource.localFallback);
    expect(snapshot.items.map((item) => item.entry.identity.normalizedTerm), [
      'most-overdue',
      'never-reviewed',
      'reviewed',
      'alpha',
      'beta',
    ]);
    expect(
      snapshot.items.every((item) => item.recommendationReason == null),
      isTrue,
    );
  });

  test(
    'ranking request contains only the approved candidate summary',
    () async {
      final now = DateTime.utc(2026, 7, 20, 8);
      final entry = _entry(
        term: 'privacy-term',
        createdAt: now.subtract(const Duration(days: 10)),
        nextReviewAt: now.subtract(const Duration(minutes: 90)),
        forgetCount: 2,
        lastReviewedAt: now.subtract(const Duration(days: 4)),
      );
      final ranker = _FakeReviewRanker((request) async {
        return ReviewAIRankResponse(
          rankedItems: [
            ReviewAIRankedItem(
              id: request.candidates.single.id,
              reason: 'Repeated misses',
            ),
          ],
        );
      });
      final controller = ReviewQueueController(
        repository: _MemoryReviewRepository([entry]),
        scheduler: ReviewScheduler(now: () => now),
        ranker: ranker,
        now: () => now,
      );

      final snapshot = await controller.buildGroup();

      final requestJson = ranker.requests.single.toJson();
      expect(requestJson.keys, {'contractVersion', 'candidates'});
      final candidate = (requestJson['candidates']! as List).single as Map;
      expect(candidate.keys, {
        'id',
        'term',
        'sourceLanguage',
        'targetLanguage',
        'translationCount',
        'consecutiveRememberedCount',
        'forgetCount',
        'overdueMinutes',
        'daysSinceLastReview',
      });
      expect(candidate['term'], 'privacy-term');
      expect(candidate['overdueMinutes'], 90);
      expect(candidate['daysSinceLastReview'], 4);
      expect(candidate['id'], isNot(contains('privacy-term')));
      expect(snapshot.items.single.entry, same(entry));
    },
  );

  test('unknown, duplicate, or incomplete AI ids fall back locally', () async {
    final now = DateTime.utc(2026, 7, 20, 8);
    final entries = ['alpha', 'beta', 'gamma']
        .map(
          (term) => _entry(
            term: term,
            createdAt: now.subtract(const Duration(days: 10)),
            nextReviewAt: now.subtract(const Duration(days: 1)),
          ),
        )
        .toList();
    final invalidResponses =
        <List<ReviewAIRankedItem> Function(ReviewAIRankRequest request)>[
          (request) => [
            ReviewAIRankedItem(id: 'unknown-id', reason: 'Invalid'),
            for (final candidate in request.candidates.skip(1))
              ReviewAIRankedItem(id: candidate.id, reason: 'Valid'),
          ],
          (request) => [
            ReviewAIRankedItem(
              id: request.candidates.first.id,
              reason: 'Duplicate one',
            ),
            ReviewAIRankedItem(
              id: request.candidates.first.id,
              reason: 'Duplicate two',
            ),
            ReviewAIRankedItem(id: request.candidates.last.id, reason: 'Valid'),
          ],
          (request) => [
            ReviewAIRankedItem(
              id: request.candidates.first.id,
              reason: 'Incomplete',
            ),
          ],
        ];

    for (final invalidResponse in invalidResponses) {
      final ranker = _FakeReviewRanker((request) async {
        return ReviewAIRankResponse(rankedItems: invalidResponse(request));
      });
      final controller = ReviewQueueController(
        repository: _MemoryReviewRepository(entries),
        scheduler: ReviewScheduler(now: () => now),
        ranker: ranker,
        now: () => now,
      );

      final snapshot = await controller.buildGroup();

      expect(snapshot.source, ReviewQueueSource.localFallback);
      expect(snapshot.items.map((item) => item.entry.identity.normalizedTerm), [
        'alpha',
        'beta',
        'gamma',
      ]);
    }
  });

  test(
    'reuses a ranking snapshot for 30 minutes without another AI call',
    () async {
      final createdAt = DateTime.utc(2026, 7, 10, 8);
      var now = DateTime.utc(2026, 7, 20, 8);
      final ranker = _FakeReviewRanker((request) async {
        return ReviewAIRankResponse(
          rankedItems: request.candidates.map(
            (candidate) =>
                ReviewAIRankedItem(id: candidate.id, reason: 'Cached ranking'),
          ),
        );
      });
      final controller = ReviewQueueController(
        repository: _MemoryReviewRepository([
          _entry(
            term: 'cacheable',
            createdAt: createdAt,
            nextReviewAt: createdAt.add(const Duration(days: 1)),
          ),
        ]),
        scheduler: ReviewScheduler(now: () => now),
        ranker: ranker,
        now: () => now,
      );

      final first = await controller.buildGroup();
      now = now.add(const Duration(minutes: 29, seconds: 59));
      final cached = await controller.buildGroup();
      now = DateTime.utc(2026, 7, 20, 8).add(const Duration(minutes: 30));
      final expired = await controller.buildGroup();

      expect(first.source, ReviewQueueSource.ai);
      expect(cached.source, ReviewQueueSource.cache);
      expect(expired.source, ReviewQueueSource.ai);
      expect(ranker.requests, hasLength(2));
    },
  );

  test(
    'caches local fallback after an AI failure to avoid retry charges',
    () async {
      final now = DateTime.utc(2026, 7, 20, 8);
      final ranker = _FakeReviewRanker((_) async {
        throw StateError('synthetic billed failure');
      });
      final controller = ReviewQueueController(
        repository: _MemoryReviewRepository([
          _entry(
            term: 'fallback-cache',
            createdAt: now.subtract(const Duration(days: 10)),
            nextReviewAt: now.subtract(const Duration(days: 1)),
          ),
        ]),
        scheduler: ReviewScheduler(now: () => now),
        ranker: ranker,
        now: () => now,
      );

      final first = await controller.buildGroup();
      final cached = await controller.buildGroup();

      expect(first.source, ReviewQueueSource.localFallback);
      expect(cached.source, ReviewQueueSource.cache);
      expect(cached.items.single.recommendationReason, isNull);
      expect(ranker.requests, hasLength(1));
    },
  );

  test(
    'feedback or history events invalidate cache and cancel review AI',
    () async {
      final now = DateTime.utc(2026, 7, 20, 8);
      final ranker = _FakeReviewRanker((request) async {
        return ReviewAIRankResponse(
          rankedItems: request.candidates.map(
            (candidate) =>
                ReviewAIRankedItem(id: candidate.id, reason: 'Fresh ranking'),
          ),
        );
      });
      final controller = ReviewQueueController(
        repository: _MemoryReviewRepository([
          _entry(
            term: 'invalidate-me',
            createdAt: now.subtract(const Duration(days: 10)),
            nextReviewAt: now.subtract(const Duration(days: 1)),
          ),
        ]),
        scheduler: ReviewScheduler(now: () => now),
        ranker: ranker,
        now: () => now,
      );
      await controller.buildGroup();
      expect((await controller.buildGroup()).source, ReviewQueueSource.cache);

      await controller.invalidate();
      final refreshed = await controller.buildGroup();

      expect(refreshed.source, ReviewQueueSource.ai);
      expect(ranker.requests, hasLength(2));
      expect(ranker.cancelCount, 1);
    },
  );

  test('a late AI response cannot restore a deleted candidate', () async {
    final now = DateTime.utc(2026, 7, 20, 8);
    final alpha = _entry(
      term: 'alpha',
      createdAt: now.subtract(const Duration(days: 10)),
      nextReviewAt: now.subtract(const Duration(days: 2)),
      generation: 1,
    );
    final beta = _entry(
      term: 'beta',
      createdAt: now.subtract(const Duration(days: 10)),
      nextReviewAt: now.subtract(const Duration(days: 1)),
      generation: 2,
    );
    final repository = _MemoryReviewRepository([alpha, beta]);
    final requestSeen = Completer<ReviewAIRankRequest>();
    final pending = Completer<ReviewAIRankResponse>();
    final ranker = _FakeReviewRanker((request) {
      requestSeen.complete(request);
      return pending.future;
    });
    final controller = ReviewQueueController(
      repository: repository,
      scheduler: ReviewScheduler(now: () => now),
      ranker: ranker,
      now: () => now,
    );

    final build = controller.buildGroup();
    final request = await requestSeen.future;
    await repository.delete(alpha.identity);
    pending.complete(
      ReviewAIRankResponse(
        rankedItems: request.candidates.map(
          (candidate) =>
              ReviewAIRankedItem(id: candidate.id, reason: 'Stale ranking'),
        ),
      ),
    );

    final snapshot = await build;

    expect(snapshot.source, ReviewQueueSource.localFallback);
    expect(snapshot.totalDueCount, 1);
    expect(snapshot.items.map((item) => item.entry.identity.normalizedTerm), [
      'beta',
    ]);
  });

  test('caches local fallback after an invalid AI response', () async {
    final now = DateTime.utc(2026, 7, 20, 8);
    final ranker = _FakeReviewRanker((_) async {
      return ReviewAIRankResponse(
        rankedItems: [
          ReviewAIRankedItem(id: 'unknown-id', reason: 'Invalid candidate'),
        ],
      );
    });
    final controller = ReviewQueueController(
      repository: _MemoryReviewRepository([
        _entry(
          term: 'invalid-cache',
          createdAt: now.subtract(const Duration(days: 10)),
          nextReviewAt: now.subtract(const Duration(days: 1)),
        ),
      ]),
      scheduler: ReviewScheduler(now: () => now),
      ranker: ranker,
      now: () => now,
    );

    expect(
      (await controller.buildGroup()).source,
      ReviewQueueSource.localFallback,
    );
    expect((await controller.buildGroup()).source, ReviewQueueSource.cache);
    expect(ranker.requests, hasLength(1));
  });

  test('a late AI response cannot replace a newer generation', () async {
    final now = DateTime.utc(2026, 7, 20, 8);
    final original = _entry(
      term: 'generation-term',
      createdAt: now.subtract(const Duration(days: 10)),
      nextReviewAt: now.subtract(const Duration(days: 1)),
      generation: 1,
    );
    final repository = _MemoryReviewRepository([original]);
    final requestSeen = Completer<ReviewAIRankRequest>();
    final pending = Completer<ReviewAIRankResponse>();
    final controller = ReviewQueueController(
      repository: repository,
      scheduler: ReviewScheduler(now: () => now),
      ranker: _FakeReviewRanker((request) {
        requestSeen.complete(request);
        return pending.future;
      }),
      now: () => now,
    );

    final build = controller.buildGroup();
    final request = await requestSeen.future;
    final rebuilt = _entry(
      term: 'generation-term',
      createdAt: original.createdAt,
      nextReviewAt: original.nextReviewAt!,
      generation: 2,
    );
    repository.entries[0] = rebuilt;
    pending.complete(
      ReviewAIRankResponse(
        rankedItems: [
          ReviewAIRankedItem(
            id: request.candidates.single.id,
            reason: 'Stale generation',
          ),
        ],
      ),
    );

    final snapshot = await build;

    expect(snapshot.source, ReviewQueueSource.localFallback);
    expect(snapshot.items.single.entry, same(rebuilt));
    expect(snapshot.items.single.recommendationReason, isNull);
  });

  test('an empty due set does not call AI', () async {
    final now = DateTime.utc(2026, 7, 20, 8);
    final ranker = _FakeReviewRanker((_) async {
      throw StateError('must not be called');
    });
    final controller = ReviewQueueController(
      repository: _MemoryReviewRepository([
        _entry(
          term: 'not-due',
          createdAt: now,
          nextReviewAt: now.add(const Duration(days: 1)),
        ),
      ]),
      scheduler: ReviewScheduler(now: () => now),
      ranker: ranker,
      now: () => now,
    );

    final snapshot = await controller.buildGroup();

    expect(snapshot.items, isEmpty);
    expect(snapshot.totalDueCount, 0);
    expect(ranker.requests, isEmpty);
  });

  test('a clock rollback never sends a negative review age to AI', () async {
    final now = DateTime.utc(2026, 7, 20, 8);
    final ranker = _FakeReviewRanker((request) async {
      return ReviewAIRankResponse(
        rankedItems: [
          ReviewAIRankedItem(
            id: request.candidates.single.id,
            reason: 'Due locally',
          ),
        ],
      );
    });
    final controller = ReviewQueueController(
      repository: _MemoryReviewRepository([
        _entry(
          term: 'clock-safe',
          createdAt: now.subtract(const Duration(days: 10)),
          nextReviewAt: now.subtract(const Duration(days: 1)),
          lastReviewedAt: now.add(const Duration(days: 1)),
        ),
      ]),
      scheduler: ReviewScheduler(now: () => now),
      ranker: ranker,
      now: () => now,
    );

    final snapshot = await controller.buildGroup();

    expect(snapshot.source, ReviewQueueSource.ai);
    expect(ranker.requests.single.candidates.single.daysSinceLastReview, 0);
  });
}

class _FakeReviewRanker implements ReviewRanker {
  _FakeReviewRanker(this._rank);

  final Future<ReviewAIRankResponse> Function(ReviewAIRankRequest request)
  _rank;
  final List<ReviewAIRankRequest> requests = [];
  int cancelCount = 0;

  @override
  String get cacheNamespace => 'fake-provider|fake-model';

  @override
  Future<void> cancelActiveRequest() async {
    cancelCount++;
  }

  @override
  Future<ReviewAIRankResponse> rank(ReviewAIRankRequest request) {
    requests.add(request);
    return _rank(request);
  }
}

class _MemoryReviewRepository implements ReviewRepository {
  _MemoryReviewRepository(Iterable<ReviewEntry> entries)
    : entries = List.of(entries);

  final List<ReviewEntry> entries;

  @override
  ReviewRepositoryState get state => ReviewRepositoryState.ready;

  @override
  Future<ReviewEntry?> applyFeedback({
    required ReviewIdentity identity,
    required ReviewFeedbackEvent event,
    required ReviewScheduler scheduler,
  }) => throw UnsupportedError('not used');

  @override
  Future<List<ReviewEntry>> all() async => List.of(entries);

  @override
  Future<void> clearAndReset() async => entries.clear();

  @override
  Future<void> delete(ReviewIdentity identity) async {
    entries.removeWhere((entry) => entry.identity == identity);
  }

  @override
  Future<ReviewEntry?> find(ReviewIdentity identity) async {
    for (final entry in entries) {
      if (entry.identity == identity) return entry;
    }
    return null;
  }

  @override
  Future<ReviewDerivedContent?> findDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required DateTime accessedAt,
  }) async => null;

  @override
  Future<bool> putDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required String mediaType,
    required List<int> bytes,
    required int expectedGeneration,
    required DateTime accessedAt,
  }) async => false;

  @override
  Future<ReviewEntry> recordTranslation({
    required ReviewIdentity identity,
    required String originalAlias,
    required DateTime translatedAt,
    required ReviewEntryContent content,
  }) {
    throw UnimplementedError();
  }
}

ReviewEntry _entry({
  required String term,
  required DateTime createdAt,
  required DateTime nextReviewAt,
  int forgetCount = 0,
  DateTime? lastReviewedAt,
  int generation = 0,
}) {
  final identity = ReviewIdentity.create(
    correctedTerm: term,
    actualSourceLanguage: TranslationSourceLanguage.en,
    targetLanguage: TranslationSourceLanguage.zh,
  );
  return ReviewEntry(
    identity: identity,
    aliases: {term},
    createdAt: createdAt,
    latestTranslatedAt: createdAt,
    translationCount: 1,
    latestContent: ReviewEntryContent(
      sourceText: term,
      translationText: 'meaning-$term',
      primaryMeaning: 'meaning-$term',
      secondaryMeanings: const [],
    ),
    forgetCount: forgetCount,
    lastReviewedAt: lastReviewedAt,
    nextReviewAt: nextReviewAt,
    generation: generation,
  );
}
