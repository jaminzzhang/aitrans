import '../domain/review_identity.dart';
import '../domain/review_feedback.dart';
import '../domain/review_scheduler.dart';
import '../models/review_entry.dart';

enum ReviewRepositoryState { ready, unavailable }

class ReviewRepositoryUnavailableException implements Exception {
  const ReviewRepositoryUnavailableException();

  @override
  String toString() => 'ReviewRepositoryUnavailableException';
}

class ReviewDerivedContent {
  ReviewDerivedContent({
    required this.identity,
    required this.contentId,
    required this.mediaType,
    required Iterable<int> bytes,
    required this.generation,
    required this.lastAccessedAt,
  }) : bytes = List<int>.unmodifiable(bytes) {
    if (contentId.trim().isEmpty || mediaType.trim().isEmpty) {
      throw ArgumentError('Derived content requires an id and media type.');
    }
    if (generation < 0 || this.bytes.any((value) => value < 0 || value > 255)) {
      throw ArgumentError('Derived content has invalid bytes or generation.');
    }
  }

  final ReviewIdentity identity;
  final String contentId;
  final String mediaType;
  final List<int> bytes;
  final int generation;
  final DateTime lastAccessedAt;

  int get byteLength => bytes.length;
}

abstract interface class ReviewCiphertextStore {
  bool get isEmpty;

  Iterable<String> get keys;

  Object? read(String key);

  Future<void> write(String key, Object value);

  Future<void> delete(String key);

  Future<void> clear();
}

abstract interface class ReviewRepository {
  ReviewRepositoryState get state;

  Future<ReviewEntry?> find(ReviewIdentity identity);

  Future<List<ReviewEntry>> all();

  Future<ReviewEntry> recordTranslation({
    required ReviewIdentity identity,
    required String originalAlias,
    required DateTime translatedAt,
    required ReviewEntryContent content,
  });

  Future<ReviewEntry?> applyFeedback({
    required ReviewIdentity identity,
    required ReviewFeedbackEvent event,
    required ReviewScheduler scheduler,
  });

  Future<bool> putDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required String mediaType,
    required List<int> bytes,
    required int expectedGeneration,
    required DateTime accessedAt,
  });

  Future<ReviewDerivedContent?> findDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required DateTime accessedAt,
  });

  Future<void> delete(ReviewIdentity identity);

  Future<void> clearAndReset();
}

class UnavailableReviewRepository implements ReviewRepository {
  const UnavailableReviewRepository();

  @override
  ReviewRepositoryState get state => ReviewRepositoryState.unavailable;

  Future<T> _unavailable<T>() =>
      Future<T>.error(const ReviewRepositoryUnavailableException());

  @override
  Future<List<ReviewEntry>> all() => _unavailable();

  @override
  Future<void> clearAndReset() => _unavailable();

  @override
  Future<void> delete(ReviewIdentity identity) => _unavailable();

  @override
  Future<ReviewEntry?> find(ReviewIdentity identity) => _unavailable();

  @override
  Future<ReviewDerivedContent?> findDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required DateTime accessedAt,
  }) => _unavailable();

  @override
  Future<bool> putDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required String mediaType,
    required List<int> bytes,
    required int expectedGeneration,
    required DateTime accessedAt,
  }) => _unavailable();

  @override
  Future<ReviewEntry> recordTranslation({
    required ReviewIdentity identity,
    required String originalAlias,
    required DateTime translatedAt,
    required ReviewEntryContent content,
  }) => _unavailable();

  @override
  Future<ReviewEntry?> applyFeedback({
    required ReviewIdentity identity,
    required ReviewFeedbackEvent event,
    required ReviewScheduler scheduler,
  }) => _unavailable();
}
