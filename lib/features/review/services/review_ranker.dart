import 'dart:async';

import '../../../core/ai/ai_provider.dart';
import '../../../core/ai/review_ai_models.dart';

abstract interface class ReviewRanker {
  String get cacheNamespace;

  Future<ReviewAIRankResponse> rank(ReviewAIRankRequest request);

  Future<void> cancelActiveRequest();
}

enum ReviewRankerFailure { timeout, cancelled, invalidResponse, unavailable }

class ReviewRankerException implements Exception {
  const ReviewRankerException(this.failure);

  final ReviewRankerFailure failure;

  @override
  String toString() => 'ReviewRankerException(${failure.name})';
}

class AIReviewRanker implements ReviewRanker {
  AIReviewRanker({
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
  Future<ReviewAIRankResponse> rank(ReviewAIRankRequest request) async {
    try {
      return await _provider.rankReviewCandidates(request).timeout(timeout);
    } on TimeoutException {
      try {
        await _provider.cancelActiveRequests();
      } on Object {
        // The timeout remains the authoritative, sanitized failure.
      }
      throw const ReviewRankerException(ReviewRankerFailure.timeout);
    } on AIProviderException catch (error) {
      final failure = switch (error.code) {
        AIProviderErrorCode.cancelled => ReviewRankerFailure.cancelled,
        AIProviderErrorCode.invalidResponse =>
          ReviewRankerFailure.invalidResponse,
        AIProviderErrorCode.invalidConfiguration ||
        AIProviderErrorCode.requestFailed ||
        AIProviderErrorCode.safetyRejected ||
        AIProviderErrorCode.unsupportedCapability =>
          ReviewRankerFailure.unavailable,
      };
      throw ReviewRankerException(failure);
    } on Object {
      throw const ReviewRankerException(ReviewRankerFailure.unavailable);
    }
  }
}
