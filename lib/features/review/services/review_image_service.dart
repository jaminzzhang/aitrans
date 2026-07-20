import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/review_ai_models.dart';
import '../data/review_repository.dart';
import '../models/review_entry.dart';

abstract interface class ReviewImageGenerator {
  ReviewAIImageCapability get capability;

  String get cacheNamespace;

  Future<ReviewAIImageResponse> generate(ReviewAIImageRequest request);

  Future<void> cancelActiveRequest();
}

enum ReviewImageFailure {
  unsupported,
  timeout,
  safetyRejected,
  cancelled,
  invalidResponse,
  unavailable,
}

class ReviewImageException implements Exception {
  const ReviewImageException(this.failure);

  final ReviewImageFailure failure;

  @override
  String toString() => 'ReviewImageException(${failure.name})';
}

class AIReviewImageGenerator implements ReviewImageGenerator {
  AIReviewImageGenerator({
    required AIProvider provider,
    this.timeout = const Duration(seconds: 30),
  }) : _provider = provider;

  final AIProvider _provider;
  final Duration timeout;

  @override
  ReviewAIImageCapability get capability => _provider.reviewImageCapability;

  @override
  String get cacheNamespace => _provider.cacheNamespace;

  @override
  Future<void> cancelActiveRequest() => _provider.cancelActiveRequests();

  @override
  Future<ReviewAIImageResponse> generate(ReviewAIImageRequest request) async {
    if (capability == ReviewAIImageCapability.unsupported) {
      throw const ReviewImageException(ReviewImageFailure.unsupported);
    }
    try {
      return await _provider.generateReviewImage(request).timeout(timeout);
    } on TimeoutException {
      try {
        await _provider.cancelActiveRequests();
      } on Object {
        // The bounded timeout remains authoritative.
      }
      throw const ReviewImageException(ReviewImageFailure.timeout);
    } on AIProviderException catch (error) {
      final failure = switch (error.code) {
        AIProviderErrorCode.cancelled => ReviewImageFailure.cancelled,
        AIProviderErrorCode.invalidResponse =>
          ReviewImageFailure.invalidResponse,
        AIProviderErrorCode.unsupportedCapability =>
          ReviewImageFailure.unsupported,
        AIProviderErrorCode.safetyRejected => ReviewImageFailure.safetyRejected,
        AIProviderErrorCode.invalidConfiguration ||
        AIProviderErrorCode.requestFailed => ReviewImageFailure.unavailable,
      };
      throw ReviewImageException(failure);
    } on Object {
      throw const ReviewImageException(ReviewImageFailure.unavailable);
    }
  }
}

enum ReviewImageLoadStatus { ready, fallback, discarded, unavailable }

enum ReviewImageSource { ai, cache }

class ReviewImageLoadResult {
  const ReviewImageLoadResult({
    required this.status,
    this.image,
    this.source,
    this.failure,
  });

  final ReviewImageLoadStatus status;
  final ReviewAIImageResponse? image;
  final ReviewImageSource? source;
  final ReviewImageFailure? failure;
}

class ReviewImageService {
  ReviewImageService({
    required ReviewRepository repository,
    required ReviewImageGenerator generator,
    required DateTime Function() now,
  }) : _repository = repository,
       _generator = generator,
       _now = now;

  static const failureMediaType =
      'application/vnd.aitrans.review-image-failure+json;version=1';

  final ReviewRepository _repository;
  final ReviewImageGenerator _generator;
  final DateTime Function() _now;
  final Map<String, Future<ReviewImageLoadResult>> _inflight = {};
  int _revision = 0;

  ReviewAIImageCapability get capability => _generator.capability;

  Future<void> invalidate() async {
    _revision++;
    try {
      await _generator.cancelActiveRequest();
    } on Object {
      // Invalidation remains authoritative if cancellation fails.
    }
  }

  Future<ReviewImageLoadResult> load(
    ReviewEntry entry, {
    bool manualRetry = false,
  }) {
    if (capability == ReviewAIImageCapability.unsupported) {
      return Future.value(
        const ReviewImageLoadResult(
          status: ReviewImageLoadStatus.fallback,
          failure: ReviewImageFailure.unsupported,
        ),
      );
    }
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

  Future<ReviewImageLoadResult> _load(
    ReviewEntry entry, {
    required String contentId,
    required bool manualRetry,
  }) async {
    if (_repository.state == ReviewRepositoryState.unavailable) {
      return const ReviewImageLoadResult(
        status: ReviewImageLoadStatus.unavailable,
      );
    }
    var requestRevision = _revision;
    var shouldPersistFailure = false;
    try {
      final cached = await _repository.findDerivedContent(
        identity: entry.identity,
        contentId: contentId,
        accessedAt: _now().toUtc(),
      );
      if (cached != null && !manualRetry) return _decodeCached(cached);

      requestRevision = _revision;
      shouldPersistFailure = true;
      final image = await _generator.generate(
        ReviewAIImageRequest(
          term: entry.identity.normalizedTerm,
          sourceLanguage: entry.identity.actualSourceLanguage.name,
          targetLanguage: entry.identity.targetLanguage.name,
          primaryMeaning: entry.latestContent.primaryMeaning,
        ),
      );
      if (requestRevision != _revision) return _discarded;
      shouldPersistFailure = false;
      final current = await _repository.find(entry.identity);
      if (current == null || current.generation != entry.generation) {
        return _discarded;
      }
      final stored = await _repository.putDerivedContent(
        identity: entry.identity,
        contentId: contentId,
        mediaType: image.mediaType,
        bytes: image.bytes,
        expectedGeneration: entry.generation,
        accessedAt: _now().toUtc(),
      );
      if (!stored) return _discarded;
      return ReviewImageLoadResult(
        status: ReviewImageLoadStatus.ready,
        image: image,
        source: ReviewImageSource.ai,
      );
    } on ReviewRepositoryUnavailableException {
      return const ReviewImageLoadResult(
        status: ReviewImageLoadStatus.unavailable,
      );
    } on ReviewImageException catch (error) {
      if (shouldPersistFailure) {
        final stored = await _persistFailure(
          entry,
          contentId: contentId,
          requestRevision: requestRevision,
          failure: error.failure,
        );
        if (!stored) return _discarded;
      }
      return ReviewImageLoadResult(
        status: ReviewImageLoadStatus.fallback,
        failure: error.failure,
      );
    } on Object {
      if (shouldPersistFailure) {
        final stored = await _persistFailure(
          entry,
          contentId: contentId,
          requestRevision: requestRevision,
          failure: ReviewImageFailure.unavailable,
        );
        if (!stored) return _discarded;
      }
      return const ReviewImageLoadResult(
        status: ReviewImageLoadStatus.fallback,
        failure: ReviewImageFailure.unavailable,
      );
    }
  }

  ReviewImageLoadResult _decodeCached(ReviewDerivedContent cached) {
    if (cached.mediaType == failureMediaType) {
      try {
        final decoded = jsonDecode(utf8.decode(cached.bytes));
        final failure = ReviewImageFailure.values.byName(
          (decoded as Map)['failure'] as String,
        );
        return ReviewImageLoadResult(
          status: ReviewImageLoadStatus.fallback,
          failure: failure,
        );
      } on Object {
        return const ReviewImageLoadResult(
          status: ReviewImageLoadStatus.fallback,
          failure: ReviewImageFailure.invalidResponse,
        );
      }
    }
    try {
      return ReviewImageLoadResult(
        status: ReviewImageLoadStatus.ready,
        image: ReviewAIImageResponse(
          mediaType: cached.mediaType,
          bytes: cached.bytes,
        ),
        source: ReviewImageSource.cache,
      );
    } on Object {
      return const ReviewImageLoadResult(
        status: ReviewImageLoadStatus.fallback,
        failure: ReviewImageFailure.invalidResponse,
      );
    }
  }

  Future<bool> _persistFailure(
    ReviewEntry entry, {
    required String contentId,
    required int requestRevision,
    required ReviewImageFailure failure,
  }) async {
    if (requestRevision != _revision) return false;
    try {
      final current = await _repository.find(entry.identity);
      if (current == null || current.generation != entry.generation) {
        return false;
      }
      return _repository.putDerivedContent(
        identity: entry.identity,
        contentId: contentId,
        mediaType: failureMediaType,
        bytes: utf8.encode(jsonEncode({'failure': failure.name})),
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
    return 'review-image-v${ReviewAIImageRequest.contractVersion}-$namespaceHash';
  }

  static const _discarded = ReviewImageLoadResult(
    status: ReviewImageLoadStatus.discarded,
  );
}
