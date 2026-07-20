import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/ai/review_ai_models.dart';
import '../data/review_repository.dart';
import '../domain/review_scheduler.dart';
import '../models/review_entry.dart';
import '../services/review_ranker.dart';

enum ReviewQueueSource { ai, cache, localFallback }

class ReviewQueueItem {
  const ReviewQueueItem({required this.entry, this.recommendationReason});

  final ReviewEntry entry;
  final String? recommendationReason;
}

class ReviewQueueSnapshot {
  ReviewQueueSnapshot({
    required Iterable<ReviewQueueItem> items,
    required this.totalDueCount,
    required this.candidateCount,
    required this.source,
  }) : items = List.unmodifiable(items);

  final List<ReviewQueueItem> items;
  final int totalDueCount;
  final int candidateCount;
  final ReviewQueueSource source;
}

class ReviewQueueController {
  ReviewQueueController({
    required ReviewRepository repository,
    required ReviewScheduler scheduler,
    required ReviewRanker ranker,
    required DateTime Function() now,
  }) : _repository = repository,
       _scheduler = scheduler,
       _ranker = ranker,
       _now = now;

  static const candidateLimit = 50;
  static const groupLimit = 10;
  static const rankingCacheTtl = Duration(minutes: 30);

  final ReviewRepository _repository;
  final ReviewScheduler _scheduler;
  final ReviewRanker _ranker;
  final DateTime Function() _now;
  final Map<String, _ReviewQueueCacheEntry> _cache = {};
  int _revision = 0;

  Future<void> invalidate() async {
    _revision++;
    _cache.clear();
    try {
      await _ranker.cancelActiveRequest();
    } on Object {
      // Invalidation must still succeed when an external cancel fails.
    }
  }

  Future<ReviewQueueSnapshot> buildGroup() async {
    final initialSelection = await _loadSelection();
    final dueEntries = initialSelection.dueEntries;
    final candidates = initialSelection.candidates;
    if (candidates.isEmpty) {
      return ReviewQueueSnapshot(
        items: const [],
        totalDueCount: 0,
        candidateCount: 0,
        source: ReviewQueueSource.localFallback,
      );
    }

    final entriesById = <String, ReviewEntry>{};
    final aiCandidates = <ReviewAICandidate>[];
    final now = _now().toUtc();
    for (final entry in candidates) {
      final id = _candidateId(entry);
      entriesById[id] = entry;
      final dueAt = _scheduler.dueAt(entry);
      final overdue = now.difference(dueAt);
      final lastReviewedAt = entry.lastReviewedAt?.toUtc();
      final reviewAge = lastReviewedAt == null
          ? null
          : now.difference(lastReviewedAt).inDays;
      aiCandidates.add(
        ReviewAICandidate(
          id: id,
          term: entry.identity.normalizedTerm,
          sourceLanguage: entry.identity.actualSourceLanguage.name,
          targetLanguage: entry.identity.targetLanguage.name,
          translationCount: entry.translationCount,
          consecutiveRememberedCount: entry.consecutiveRememberedCount,
          forgetCount: entry.forgetCount,
          overdueMinutes: overdue.isNegative ? 0 : overdue.inMinutes,
          daysSinceLastReview: reviewAge == null
              ? null
              : reviewAge < 0
              ? 0
              : reviewAge,
        ),
      );
    }

    final cacheKey = _cacheKey(candidates);
    final cached = _cache[cacheKey];
    if (cached != null && _now().toUtc().isBefore(cached.expiresAt)) {
      return ReviewQueueSnapshot(
        items: cached.items.map(
          (item) => ReviewQueueItem(
            entry: entriesById[item.id]!,
            recommendationReason: item.reason,
          ),
        ),
        totalDueCount: dueEntries.length,
        candidateCount: candidates.length,
        source: ReviewQueueSource.cache,
      );
    }
    _cache.remove(cacheKey);

    final buildRevision = _revision;
    ReviewAIRankResponse? response;
    try {
      response = await _ranker.rank(
        ReviewAIRankRequest(candidates: aiCandidates),
      );
    } on Object {
      response = null;
    }

    final currentSelection = await _loadSelection();
    final currentCacheKey = _cacheKey(currentSelection.candidates);
    if (buildRevision != _revision || currentCacheKey != cacheKey) {
      return _localSnapshot(
        dueEntries: currentSelection.dueEntries,
        candidates: currentSelection.candidates,
      );
    }

    if (response == null) {
      _cacheLocalFallback(cacheKey, candidates);
      return _localSnapshot(dueEntries: dueEntries, candidates: candidates);
    }
    final expectedItemCount = candidates.length < groupLimit
        ? candidates.length
        : groupLimit;
    final rankedItems = response.rankedItems;
    final rankedIds = rankedItems.map((item) => item.id).toSet();
    if (rankedItems.length != expectedItemCount ||
        rankedIds.length != rankedItems.length ||
        rankedIds.any((id) => !entriesById.containsKey(id))) {
      _cacheLocalFallback(cacheKey, candidates);
      return _localSnapshot(dueEntries: dueEntries, candidates: candidates);
    }
    final items = rankedItems.map((ranked) {
      return ReviewQueueItem(
        entry: entriesById[ranked.id]!,
        recommendationReason: ranked.reason,
      );
    });
    _cache[cacheKey] = _ReviewQueueCacheEntry(
      items: rankedItems.map(
        (item) => _ReviewQueueCacheItem(id: item.id, reason: item.reason),
      ),
      expiresAt: _now().toUtc().add(rankingCacheTtl),
    );
    return ReviewQueueSnapshot(
      items: items,
      totalDueCount: dueEntries.length,
      candidateCount: candidates.length,
      source: ReviewQueueSource.ai,
    );
  }

  ReviewQueueSnapshot _localSnapshot({
    required List<ReviewEntry> dueEntries,
    required List<ReviewEntry> candidates,
  }) {
    return ReviewQueueSnapshot(
      items: candidates
          .take(groupLimit)
          .map((entry) => ReviewQueueItem(entry: entry)),
      totalDueCount: dueEntries.length,
      candidateCount: candidates.length,
      source: ReviewQueueSource.localFallback,
    );
  }

  void _cacheLocalFallback(String cacheKey, List<ReviewEntry> candidates) {
    _cache[cacheKey] = _ReviewQueueCacheEntry(
      items: candidates
          .take(groupLimit)
          .map(
            (entry) =>
                _ReviewQueueCacheItem(id: _candidateId(entry), reason: null),
          ),
      expiresAt: _now().toUtc().add(rankingCacheTtl),
    );
  }

  Future<_ReviewCandidateSelection> _loadSelection() async {
    final allEntries = await _repository.all();
    final dueEntries = allEntries.where(_scheduler.isDue).toList()
      ..sort(_compareEntries);
    return _ReviewCandidateSelection(
      dueEntries: dueEntries,
      candidates: dueEntries.take(candidateLimit),
    );
  }

  int _compareEntries(ReviewEntry left, ReviewEntry right) {
    final byDue = _scheduler.dueAt(left).compareTo(_scheduler.dueAt(right));
    if (byDue != 0) return byDue;
    final byForget = right.forgetCount.compareTo(left.forgetCount);
    if (byForget != 0) return byForget;
    final leftReview = left.lastReviewedAt?.toUtc();
    final rightReview = right.lastReviewedAt?.toUtc();
    if (leftReview == null && rightReview != null) return -1;
    if (leftReview != null && rightReview == null) return 1;
    final byReview = leftReview?.compareTo(rightReview!) ?? 0;
    if (byReview != 0) return byReview;
    final byTerm = left.identity.normalizedTerm.compareTo(
      right.identity.normalizedTerm,
    );
    if (byTerm != 0) return byTerm;
    final bySource = left.identity.actualSourceLanguage.name.compareTo(
      right.identity.actualSourceLanguage.name,
    );
    if (bySource != 0) return bySource;
    return left.identity.targetLanguage.name.compareTo(
      right.identity.targetLanguage.name,
    );
  }

  String _candidateId(ReviewEntry entry) {
    final identity = jsonEncode(entry.identity.toJson());
    return 'candidate-${sha256.convert(utf8.encode(identity))}';
  }

  String _cacheKey(List<ReviewEntry> candidates) {
    final canonical = jsonEncode({
      'contractVersion': ReviewAIRankRequest.contractVersion,
      'provider': _ranker.cacheNamespace,
      'candidates': candidates.map((entry) {
        return {
          'id': _candidateId(entry),
          'generation': entry.generation,
          'dueAt': _scheduler.dueAt(entry).toIso8601String(),
          'latestTranslatedAt': entry.latestTranslatedAt
              .toUtc()
              .toIso8601String(),
          'translationCount': entry.translationCount,
          'consecutiveRememberedCount': entry.consecutiveRememberedCount,
          'forgetCount': entry.forgetCount,
          'lastReviewedAt': entry.lastReviewedAt?.toUtc().toIso8601String(),
          'forcedDue': entry.forcedDue,
        };
      }).toList(),
    });
    return sha256.convert(utf8.encode(canonical)).toString();
  }
}

class _ReviewQueueCacheEntry {
  _ReviewQueueCacheEntry({
    required Iterable<_ReviewQueueCacheItem> items,
    required this.expiresAt,
  }) : items = List.unmodifiable(items);

  final List<_ReviewQueueCacheItem> items;
  final DateTime expiresAt;
}

class _ReviewCandidateSelection {
  _ReviewCandidateSelection({
    required Iterable<ReviewEntry> dueEntries,
    required Iterable<ReviewEntry> candidates,
  }) : dueEntries = List.unmodifiable(dueEntries),
       candidates = List.unmodifiable(candidates);

  final List<ReviewEntry> dueEntries;
  final List<ReviewEntry> candidates;
}

class _ReviewQueueCacheItem {
  const _ReviewQueueCacheItem({required this.id, required this.reason});

  final String id;
  final String? reason;
}
