import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/review_ai_models.dart';
import '../data/review_repository.dart';
import '../models/review_content.dart';
import '../models/review_entry.dart';

abstract interface class ReviewTextContentGenerator {
  String get cacheNamespace;

  Future<ReviewAITextContentResponse> generate(
    ReviewAITextContentRequest request,
  );

  Future<void> cancelActiveRequest();
}

enum ReviewTextContentFailure {
  timeout,
  cancelled,
  invalidResponse,
  unavailable,
}

class ReviewTextContentException implements Exception {
  const ReviewTextContentException(this.failure);

  final ReviewTextContentFailure failure;

  @override
  String toString() => 'ReviewTextContentException(${failure.name})';
}

class AIReviewTextContentGenerator implements ReviewTextContentGenerator {
  AIReviewTextContentGenerator({
    required AIProvider provider,
    this.timeout = const Duration(seconds: 20),
  }) : _provider = provider;

  final AIProvider _provider;
  final Duration timeout;

  @override
  String get cacheNamespace => _provider.cacheNamespace;

  @override
  Future<void> cancelActiveRequest() => _provider.cancelActiveRequests();

  @override
  Future<ReviewAITextContentResponse> generate(
    ReviewAITextContentRequest request,
  ) async {
    try {
      return await _provider
          .generateReviewTextContent(request)
          .timeout(timeout);
    } on TimeoutException {
      try {
        await _provider.cancelActiveRequests();
      } on Object {
        // Timeout remains the authoritative sanitized failure.
      }
      throw const ReviewTextContentException(ReviewTextContentFailure.timeout);
    } on AIProviderException catch (error) {
      final failure = switch (error.code) {
        AIProviderErrorCode.cancelled => ReviewTextContentFailure.cancelled,
        AIProviderErrorCode.invalidResponse =>
          ReviewTextContentFailure.invalidResponse,
        AIProviderErrorCode.invalidConfiguration ||
        AIProviderErrorCode.requestFailed ||
        AIProviderErrorCode.safetyRejected ||
        AIProviderErrorCode.unsupportedCapability =>
          ReviewTextContentFailure.unavailable,
      };
      throw ReviewTextContentException(failure);
    } on Object {
      throw const ReviewTextContentException(
        ReviewTextContentFailure.unavailable,
      );
    }
  }
}

enum ReviewContentLoadStatus { ready, degraded, discarded, unavailable }

enum ReviewContentSource { ai, cache }

class ReviewContentLoadResult {
  const ReviewContentLoadResult({
    required this.status,
    this.content,
    this.source,
  });

  final ReviewContentLoadStatus status;
  final ReviewTextContent? content;
  final ReviewContentSource? source;
}

class ReviewContentService {
  ReviewContentService({
    required ReviewRepository repository,
    required ReviewTextContentGenerator generator,
    required DateTime Function() now,
  }) : _repository = repository,
       _generator = generator,
       _now = now;

  static const String mediaType =
      'application/vnd.aitrans.review-text+json;version=1';

  final ReviewRepository _repository;
  final ReviewTextContentGenerator _generator;
  final DateTime Function() _now;
  final Map<String, Future<ReviewContentLoadResult>> _inflight = {};
  int _revision = 0;

  String get cacheNamespace => _generator.cacheNamespace;

  Future<void> invalidate() async {
    _revision++;
    try {
      await _generator.cancelActiveRequest();
    } on Object {
      // Invalidation remains authoritative when external cancellation fails.
    }
  }

  Future<ReviewContentLoadResult> load(
    ReviewEntry entry, {
    bool manualRetry = false,
  }) {
    final contentId = _contentId();
    final inflightKey = '${entry.identity.toJson()}|$contentId';
    if (!manualRetry) {
      final existing = _inflight[inflightKey];
      if (existing != null) return existing;
    }
    final future = _load(entry, contentId: contentId, manualRetry: manualRetry);
    _inflight[inflightKey] = future;
    return future.whenComplete(() {
      if (identical(_inflight[inflightKey], future)) {
        _inflight.remove(inflightKey);
      }
    });
  }

  Future<ReviewContentLoadResult> _load(
    ReviewEntry entry, {
    required String contentId,
    required bool manualRetry,
  }) async {
    if (_repository.state == ReviewRepositoryState.unavailable) {
      return const ReviewContentLoadResult(
        status: ReviewContentLoadStatus.unavailable,
      );
    }
    var shouldPersistFailure = false;
    var requestRevision = _revision;
    try {
      final cached = await _repository.findDerivedContent(
        identity: entry.identity,
        contentId: contentId,
        accessedAt: _now().toUtc(),
      );
      if (cached != null && !manualRetry) {
        return _decodeCached(cached);
      }

      requestRevision = _revision;
      shouldPersistFailure = true;
      final response = await _generator.generate(
        ReviewAITextContentRequest(
          term: entry.identity.normalizedTerm,
          sourceLanguage: entry.identity.actualSourceLanguage.name,
          targetLanguage: entry.identity.targetLanguage.name,
          primaryMeaning: entry.latestContent.primaryMeaning,
        ),
      );
      if (requestRevision != _revision) {
        return const ReviewContentLoadResult(
          status: ReviewContentLoadStatus.discarded,
        );
      }
      shouldPersistFailure = false;
      final current = await _repository.find(entry.identity);
      if (current == null || current.generation != entry.generation) {
        return const ReviewContentLoadResult(
          status: ReviewContentLoadStatus.discarded,
        );
      }
      final content = ReviewTextContent.fromAI(response);
      final stored = await _repository.putDerivedContent(
        identity: entry.identity,
        contentId: contentId,
        mediaType: mediaType,
        bytes: utf8.encode(jsonEncode(_readyCacheJson(content))),
        expectedGeneration: entry.generation,
        accessedAt: _now().toUtc(),
      );
      if (!stored) {
        return const ReviewContentLoadResult(
          status: ReviewContentLoadStatus.discarded,
        );
      }
      return ReviewContentLoadResult(
        status: ReviewContentLoadStatus.ready,
        content: content,
        source: ReviewContentSource.ai,
      );
    } on ReviewRepositoryUnavailableException {
      return const ReviewContentLoadResult(
        status: ReviewContentLoadStatus.unavailable,
      );
    } on Object {
      if (shouldPersistFailure) {
        final persisted = await _persistFailureMarker(
          entry,
          contentId: contentId,
          requestRevision: requestRevision,
        );
        if (!persisted) {
          return const ReviewContentLoadResult(
            status: ReviewContentLoadStatus.discarded,
          );
        }
      }
      return const ReviewContentLoadResult(
        status: ReviewContentLoadStatus.degraded,
      );
    }
  }

  ReviewContentLoadResult _decodeCached(ReviewDerivedContent cached) {
    if (cached.mediaType != mediaType) {
      return const ReviewContentLoadResult(
        status: ReviewContentLoadStatus.degraded,
      );
    }
    try {
      final decoded = jsonDecode(utf8.decode(cached.bytes));
      if (decoded is! Map) {
        throw const FormatException('Malformed review content cache.');
      }
      if (decoded.length == 1 && decoded['status'] == 'failed') {
        return const ReviewContentLoadResult(
          status: ReviewContentLoadStatus.degraded,
        );
      }
      if (decoded.length != 2 ||
          decoded['status'] != 'ready' ||
          decoded['content'] is! Map) {
        throw const FormatException('Malformed review content cache.');
      }
      return ReviewContentLoadResult(
        status: ReviewContentLoadStatus.ready,
        content: ReviewTextContent.fromJson(
          (decoded['content'] as Map).cast<String, dynamic>(),
        ),
        source: ReviewContentSource.cache,
      );
    } on Object {
      return const ReviewContentLoadResult(
        status: ReviewContentLoadStatus.degraded,
      );
    }
  }

  Map<String, Object> _readyCacheJson(ReviewTextContent content) => {
    'status': 'ready',
    'content': content.toJson(),
  };

  Future<bool> _persistFailureMarker(
    ReviewEntry entry, {
    required String contentId,
    required int requestRevision,
  }) async {
    if (requestRevision != _revision) return false;
    try {
      final current = await _repository.find(entry.identity);
      if (current == null || current.generation != entry.generation) {
        return false;
      }
      return await _repository.putDerivedContent(
        identity: entry.identity,
        contentId: contentId,
        mediaType: mediaType,
        bytes: utf8.encode(jsonEncode(const {'status': 'failed'})),
        expectedGeneration: entry.generation,
        accessedAt: _now().toUtc(),
      );
    } on Object {
      return false;
    }
  }

  String _contentId() {
    final namespaceHash = sha256
        .convert(utf8.encode(_generator.cacheNamespace))
        .toString();
    return 'review-text-v${ReviewTextContent.schemaVersion}-$namespaceHash';
  }
}
