import 'dart:convert';

import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/logic/review_capture_service.dart';
import 'package:aitrans/features/review/logic/review_queue_controller.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/review/services/review_content_service.dart';
import 'package:aitrans/features/review/services/review_image_service.dart';
import 'package:aitrans/features/review/services/review_ranker.dart';
import 'package:aitrans/features/review/ui/review_card.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:aitrans/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'translation becomes a ranked card, records feedback, and becomes due again',
    (tester) async {
      var now = DateTime.utc(2026, 7, 20, 8);
      final repository = _MemoryRepository();
      final scheduler = ReviewScheduler(now: () => now);
      final ranker = _Ranker();
      final queue = ReviewQueueController(
        repository: repository,
        scheduler: scheduler,
        ranker: ranker,
        now: () => now,
      );
      final capture = ReviewCaptureService(
        repository: repository,
        isCaptureEnabled: () => true,
        now: () => now,
      );

      final captured = await capture.capture(
        originalSource: 'break teh ice',
        targetLanguage: TranslationSourceLanguage.zh,
        presentation: const TranslationPresentation(
          correctedSource: 'break the ice',
          adoptedSource: 'break the ice',
          actualSourceLanguage: TranslationSourceLanguage.en,
          reviewClassificationVersion: 1,
          semanticClass: TranslationSemanticClass.phrase,
          translationText: '打破僵局',
          primaryMeaning: '打破僵局',
          partOfSpeech: 'idiom',
          secondaryMeanings: ['活跃气氛'],
        ),
      );

      expect(captured.status, ReviewCaptureStatus.captured);
      expect(repository.entries, hasLength(1));
      expect((await queue.buildGroup()).items, isEmpty);

      now = now.add(const Duration(hours: 24));
      final dueGroup = await queue.buildGroup();
      expect(dueGroup.source, ReviewQueueSource.ai);
      expect(dueGroup.items, hasLength(1));
      expect(dueGroup.items.single.recommendationReason, '近期容易忘记');

      final textGenerator = _TextGenerator();
      final imageGenerator = _ImageGenerator();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ReviewDeck(
              items: dueGroup.items,
              contentService: ReviewContentService(
                repository: repository,
                generator: textGenerator,
                now: () => now,
              ),
              imageService: ReviewImageService(
                repository: repository,
                generator: imageGenerator,
                now: () => now,
              ),
              onFeedback: (entry, feedback) async {
                await queue.invalidate();
                return await repository.applyFeedback(
                      identity: entry.identity,
                      event: ReviewFeedbackEvent(
                        id: 'closed-loop-feedback-1',
                        feedback: feedback,
                      ),
                      scheduler: scheduler,
                    ) !=
                    null;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('break the ice'), findsOneWidget);
      expect(find.text('打破僵局'), findsOneWidget);
      expect(find.text('生活常用语'), findsOneWidget);
      expect(find.text('AI 生成插图'), findsOneWidget);
      expect(textGenerator.callCount, 1);
      expect(imageGenerator.callCount, 1);

      await tester.tap(find.byKey(const ValueKey('feedback-forgotten')));
      await tester.pumpAndSettle();
      final reviewed = repository.entries.single;
      expect(reviewed.forgetCount, 1);
      expect(reviewed.nextReviewAt, now.add(const Duration(minutes: 10)));
      expect(reviewed.appliedFeedbackEventIds, {'closed-loop-feedback-1'});
      expect((await queue.buildGroup()).items, isEmpty);

      now = now.add(const Duration(minutes: 10));
      final dueAgain = await queue.buildGroup();
      expect(dueAgain.items.single.entry.identity, reviewed.identity);
      expect(ranker.callCount, 2);
    },
  );
}

class _Ranker implements ReviewRanker {
  int callCount = 0;

  @override
  String get cacheNamespace => 'closed-loop-ranker|model-1';

  @override
  Future<void> cancelActiveRequest() async {}

  @override
  Future<ReviewAIRankResponse> rank(ReviewAIRankRequest request) async {
    callCount++;
    return ReviewAIRankResponse(
      rankedItems: request.candidates
          .take(10)
          .map(
            (candidate) =>
                ReviewAIRankedItem(id: candidate.id, reason: '近期容易忘记'),
          ),
    );
  }
}

class _TextGenerator implements ReviewTextContentGenerator {
  int callCount = 0;

  @override
  String get cacheNamespace => 'closed-loop-text|model-1';

  @override
  Future<void> cancelActiveRequest() async {}

  @override
  Future<ReviewAITextContentResponse> generate(
    ReviewAITextContentRequest request,
  ) async {
    callCount++;
    return ReviewAITextContentResponse(
      everydayUsages: [
        ReviewAIEverydayUsage(
          situation: '初次见面',
          original: 'A game helped break the ice.',
          translation: '游戏帮助大家打破了僵局。',
        ),
      ],
      fictionalDialogue: ReviewAIFictionalDialogue(
        dialogue: 'Let us break the ice.',
        translation: '让我们先活跃一下气氛。',
      ),
    );
  }
}

class _ImageGenerator implements ReviewImageGenerator {
  int callCount = 0;

  @override
  ReviewAIImageCapability get capability => ReviewAIImageCapability.supported;

  @override
  String get cacheNamespace => 'closed-loop-image|model-1';

  @override
  Future<void> cancelActiveRequest() async {}

  @override
  Future<ReviewAIImageResponse> generate(ReviewAIImageRequest request) async {
    callCount++;
    return ReviewAIImageResponse(
      mediaType: 'image/png',
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
        'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  }
}

class _MemoryRepository implements ReviewRepository {
  final List<ReviewEntry> entries = [];
  final Map<String, ReviewDerivedContent> _derived = {};
  int _generation = 0;

  String _contentKey(ReviewIdentity identity, String contentId) =>
      '${identity.toJson()}|$contentId';

  @override
  ReviewRepositoryState get state => ReviewRepositoryState.ready;

  @override
  Future<ReviewEntry?> applyFeedback({
    required ReviewIdentity identity,
    required ReviewFeedbackEvent event,
    required ReviewScheduler scheduler,
  }) async {
    final index = entries.indexWhere((entry) => entry.identity == identity);
    if (index < 0) return null;
    final existing = entries[index];
    final updated = scheduler
        .applyFeedback(
          state: ReviewScheduleState(
            entry: existing,
            appliedFeedbackEventIds: existing.appliedFeedbackEventIds,
          ),
          event: event,
        )
        .entry;
    entries[index] = updated;
    return updated;
  }

  @override
  Future<List<ReviewEntry>> all() async => List.unmodifiable(entries);

  @override
  Future<void> clearAndReset() async {
    entries.clear();
    _derived.clear();
  }

  @override
  Future<void> delete(ReviewIdentity identity) async {
    entries.removeWhere((entry) => entry.identity == identity);
    _derived.removeWhere((_, content) => content.identity == identity);
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
  }) async => _derived[_contentKey(identity, contentId)];

  @override
  Future<bool> putDerivedContent({
    required ReviewIdentity identity,
    required String contentId,
    required String mediaType,
    required List<int> bytes,
    required int expectedGeneration,
    required DateTime accessedAt,
  }) async {
    final entry = await find(identity);
    if (entry == null || entry.generation != expectedGeneration) return false;
    _derived[_contentKey(identity, contentId)] = ReviewDerivedContent(
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
  }) async {
    final index = entries.indexWhere((entry) => entry.identity == identity);
    if (index < 0) {
      final entry = ReviewEntry.firstTranslation(
        identity: identity,
        originalAlias: originalAlias,
        translatedAt: translatedAt,
        content: content,
        generation: _generation++,
      );
      entries.add(entry);
      return entry;
    }
    final updated = entries[index].recordTranslation(
      originalAlias: originalAlias,
      translatedAt: translatedAt,
      content: content,
    );
    entries[index] = updated;
    return updated;
  }
}
