import '../../translate/models/translation_presentation.dart';
import '../data/review_repository.dart';
import '../domain/review_eligibility.dart';
import '../domain/review_identity.dart';
import '../models/review_entry.dart';

enum ReviewCaptureStatus { captured, excluded, disabled, unavailable, failed }

class ReviewCaptureResult {
  const ReviewCaptureResult({required this.status, this.exclusionReason});

  final ReviewCaptureStatus status;
  final ReviewEligibilityExclusionReason? exclusionReason;
}

abstract interface class ReviewCapture {
  Future<ReviewCaptureResult> capture({
    required String originalSource,
    required TranslationSourceLanguage targetLanguage,
    required TranslationPresentation presentation,
  });
}

class ReviewCaptureService implements ReviewCapture {
  ReviewCaptureService({
    required ReviewRepository repository,
    required bool Function() isCaptureEnabled,
    required DateTime Function() now,
  }) : _repository = repository,
       _isCaptureEnabled = isCaptureEnabled,
       _now = now;

  final ReviewRepository _repository;
  final bool Function() _isCaptureEnabled;
  final DateTime Function() _now;

  @override
  Future<ReviewCaptureResult> capture({
    required String originalSource,
    required TranslationSourceLanguage targetLanguage,
    required TranslationPresentation presentation,
  }) async {
    if (!_isCaptureEnabled()) {
      return const ReviewCaptureResult(status: ReviewCaptureStatus.disabled);
    }
    final eligibility = ReviewEligibility.evaluate(
      originalSource: originalSource,
      adoptedSource: presentation.adoptedSource,
      actualSourceLanguage: presentation.actualSourceLanguage,
      semanticClass: presentation.semanticClass,
      classificationVersion: presentation.reviewClassificationVersion,
    );
    if (!eligibility.isEligible) {
      return ReviewCaptureResult(
        status: ReviewCaptureStatus.excluded,
        exclusionReason: eligibility.exclusionReason,
      );
    }
    if (_repository.state != ReviewRepositoryState.ready) {
      return const ReviewCaptureResult(status: ReviewCaptureStatus.unavailable);
    }

    try {
      final identity = ReviewIdentity.create(
        correctedTerm: presentation.adoptedSource,
        actualSourceLanguage: presentation.actualSourceLanguage,
        targetLanguage: targetLanguage,
      );
      final content = ReviewEntryContent(
        sourceText: presentation.adoptedSource,
        translationText: presentation.translationText,
        primaryMeaning: presentation.primaryMeaning,
        partOfSpeech: presentation.partOfSpeech,
        pronunciation: presentation.pronunciation,
        secondaryMeanings: presentation.secondaryMeanings,
      );
      await _repository.recordTranslation(
        identity: identity,
        originalAlias: originalSource,
        translatedAt: _now().toUtc(),
        content: content,
      );
      return const ReviewCaptureResult(status: ReviewCaptureStatus.captured);
    } on ReviewRepositoryUnavailableException {
      return const ReviewCaptureResult(status: ReviewCaptureStatus.unavailable);
    } catch (_) {
      return const ReviewCaptureResult(status: ReviewCaptureStatus.failed);
    }
  }
}
