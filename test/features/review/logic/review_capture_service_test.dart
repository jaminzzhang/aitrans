import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/domain/review_eligibility.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/logic/review_capture_service.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'captures an eligible corrected phrase with its original alias',
    () async {
      final translatedAt = DateTime.utc(2026, 7, 19, 8, 30);
      final repository = _RecordingReviewRepository();
      final service = ReviewCaptureService(
        repository: repository,
        isCaptureEnabled: () => true,
        now: () => translatedAt,
      );
      const presentation = TranslationPresentation(
        correctedSource: 'the cat',
        adoptedSource: 'the cat',
        actualSourceLanguage: TranslationSourceLanguage.en,
        reviewClassificationVersion: 1,
        semanticClass: TranslationSemanticClass.phrase,
        translationText: '这只猫\nPOS: noun\n猫科动物',
        primaryMeaning: '这只猫',
        partOfSpeech: 'noun',
        secondaryMeanings: ['猫科动物'],
      );

      final result = await service.capture(
        originalSource: 'teh cat',
        targetLanguage: TranslationSourceLanguage.zh,
        presentation: presentation,
      );

      expect(result.status, ReviewCaptureStatus.captured);
      expect(repository.recordCalls, 1);
      expect(repository.recordedIdentity?.normalizedTerm, 'the cat');
      expect(
        repository.recordedIdentity?.actualSourceLanguage,
        TranslationSourceLanguage.en,
      );
      expect(
        repository.recordedIdentity?.targetLanguage,
        TranslationSourceLanguage.zh,
      );
      expect(repository.recordedAlias, 'teh cat');
      expect(repository.recordedAt, translatedAt);
      expect(repository.recordedContent?.sourceText, 'the cat');
      expect(repository.recordedContent?.primaryMeaning, '这只猫');
      expect(repository.recordedContent?.partOfSpeech, 'noun');
      expect(repository.recordedContent?.secondaryMeanings, ['猫科动物']);
    },
  );

  test('disabled capture never touches the repository', () async {
    final repository = _RecordingReviewRepository();
    final service = ReviewCaptureService(
      repository: repository,
      isCaptureEnabled: () => false,
      now: () => DateTime.utc(2026, 7, 19),
    );

    final result = await service.capture(
      originalSource: 'hello',
      targetLanguage: TranslationSourceLanguage.zh,
      presentation: _eligibleWordPresentation(),
    );

    expect(result.status, ReviewCaptureStatus.disabled);
    expect(repository.recordCalls, 0);
  });

  test('an unavailable repository returns a redacted status', () async {
    final repository = _RecordingReviewRepository(
      repositoryState: ReviewRepositoryState.unavailable,
    );
    final service = ReviewCaptureService(
      repository: repository,
      isCaptureEnabled: () => true,
      now: () => DateTime.utc(2026, 7, 19),
    );

    final result = await service.capture(
      originalSource: 'hello',
      targetLanguage: TranslationSourceLanguage.zh,
      presentation: _eligibleWordPresentation(),
    );

    expect(result.status, ReviewCaptureStatus.unavailable);
    expect(repository.recordCalls, 0);
  });

  test('a repository write failure is contained and redacted', () async {
    final repository = _RecordingReviewRepository(
      writeError: StateError(
        'synthetic path and user text that must never reach capture status',
      ),
    );
    final service = ReviewCaptureService(
      repository: repository,
      isCaptureEnabled: () => true,
      now: () => DateTime.utc(2026, 7, 19),
    );

    final result = await service.capture(
      originalSource: 'hello',
      targetLanguage: TranslationSourceLanguage.zh,
      presentation: _eligibleWordPresentation(),
    );

    expect(result.status, ReviewCaptureStatus.failed);
    expect(result.toString(), isNot(contains('synthetic')));
    expect(result.toString(), isNot(contains('hello')));
    expect(repository.recordCalls, 1);
  });

  test(
    'a non-reviewable sentence is excluded before repository access',
    () async {
      final repository = _RecordingReviewRepository(
        repositoryState: ReviewRepositoryState.unavailable,
      );
      final service = ReviewCaptureService(
        repository: repository,
        isCaptureEnabled: () => true,
        now: () => DateTime.utc(2026, 7, 19),
      );
      final presentation = TranslationPresentation(
        adoptedSource: 'This is a complete sentence.',
        actualSourceLanguage: TranslationSourceLanguage.en,
        reviewClassificationVersion: 1,
        semanticClass: TranslationSemanticClass.sentence,
        translationText: '这是一个完整句子。',
        primaryMeaning: '这是一个完整句子。',
        secondaryMeanings: const [],
      );

      final result = await service.capture(
        originalSource: 'This is a complete sentence.',
        targetLanguage: TranslationSourceLanguage.zh,
        presentation: presentation,
      );

      expect(result.status, ReviewCaptureStatus.excluded);
      expect(
        result.exclusionReason,
        ReviewEligibilityExclusionReason.semanticClassNotReviewable,
      );
      expect(repository.recordCalls, 0);
    },
  );
}

TranslationPresentation _eligibleWordPresentation() {
  return const TranslationPresentation(
    adoptedSource: 'hello',
    actualSourceLanguage: TranslationSourceLanguage.en,
    reviewClassificationVersion: 1,
    semanticClass: TranslationSemanticClass.word,
    translationText: '你好',
    primaryMeaning: '你好',
    secondaryMeanings: [],
  );
}

class _RecordingReviewRepository implements ReviewRepository {
  _RecordingReviewRepository({
    this.repositoryState = ReviewRepositoryState.ready,
    this.writeError,
  });

  final ReviewRepositoryState repositoryState;
  final Object? writeError;
  int recordCalls = 0;
  ReviewIdentity? recordedIdentity;
  String? recordedAlias;
  DateTime? recordedAt;
  ReviewEntryContent? recordedContent;

  @override
  ReviewRepositoryState get state => repositoryState;

  @override
  Future<ReviewEntry?> applyFeedback({
    required ReviewIdentity identity,
    required ReviewFeedbackEvent event,
    required ReviewScheduler scheduler,
  }) => throw UnsupportedError('not used');

  @override
  Future<ReviewEntry> recordTranslation({
    required ReviewIdentity identity,
    required String originalAlias,
    required DateTime translatedAt,
    required ReviewEntryContent content,
  }) async {
    recordCalls++;
    if (writeError case final error?) throw error;
    recordedIdentity = identity;
    recordedAlias = originalAlias;
    recordedAt = translatedAt;
    recordedContent = content;
    return ReviewEntry.firstTranslation(
      identity: identity,
      originalAlias: originalAlias,
      translatedAt: translatedAt,
      content: content,
    );
  }

  @override
  Future<List<ReviewEntry>> all() async => const [];

  @override
  Future<void> clearAndReset() async {}

  @override
  Future<void> delete(ReviewIdentity identity) async {}

  @override
  Future<ReviewEntry?> find(ReviewIdentity identity) async => null;

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
}
