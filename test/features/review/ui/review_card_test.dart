import 'dart:async';
import 'dart:convert';

import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/logic/review_queue_controller.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/review/services/review_content_service.dart';
import 'package:aitrans/features/review/services/review_image_service.dart';
import 'package:aitrans/features/review/ui/review_card.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:aitrans/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows saved meaning immediately and only loads the current card',
    (tester) async {
      final first = _entry(
        term: 'break the ice',
        meaning: '打破僵局',
        partOfSpeech: 'idiom',
        pronunciation: '/breɪk ði aɪs/',
        secondaryMeanings: const ['活跃气氛'],
      );
      final second = _entry(term: 'world', meaning: '世界');
      final repository = _MemoryRepository([first, second]);
      final generator = _ControlledGenerator();
      final service = ReviewContentService(
        repository: repository,
        generator: generator,
        now: () => DateTime.utc(2026, 7, 20, 12),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ReviewDeck(
              items: [
                ReviewQueueItem(entry: first, recommendationReason: '最近容易忘记'),
                ReviewQueueItem(entry: second),
              ],
              contentService: service,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('break the ice'), findsOneWidget);
      expect(find.text('打破僵局'), findsOneWidget);
      expect(find.text('idiom'), findsOneWidget);
      expect(find.text('/breɪk ði aɪs/'), findsOneWidget);
      expect(find.text('活跃气氛'), findsOneWidget);
      expect(generator.requests, hasLength(1));
      expect(generator.requests.single.term, 'break the ice');

      generator.completeNext();
      await tester.pumpAndSettle();

      expect(find.text('生活常用语'), findsOneWidget);
      expect(find.text('初次见面'), findsOneWidget);
      expect(find.text('影视化场景对白'), findsOneWidget);
      expect(find.textContaining('AI 创作的虚构对白'), findsOneWidget);
      expect(find.textContaining('真实影片'), findsNothing);
      expect(generator.requests, hasLength(1));

      await tester.tap(find.byKey(const ValueKey('next-review-card')));
      await tester.pump();

      expect(find.text('world'), findsOneWidget);
      expect(generator.requests, hasLength(2));
      expect(generator.requests.last.term, 'world');
    },
  );

  testWidgets('failed text stays degraded until the user retries', (
    tester,
  ) async {
    final entry = _entry(term: 'hello', meaning: '你好');
    final repository = _MemoryRepository([entry]);
    final generator = _FailingThenSuccessfulGenerator();
    final service = ReviewContentService(
      repository: repository,
      generator: generator,
      now: () => DateTime.utc(2026, 7, 20, 13),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ReviewDeck(
            items: [ReviewQueueItem(entry: entry)],
            contentService: service,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('扩展内容暂不可用，已显示保存的词义'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-review-text')), findsOneWidget);
    expect(generator.callCount, 1);
    expect(find.textContaining('/private/path'), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(generator.callCount, 1);

    await tester.tap(find.byKey(const ValueKey('retry-review-text')));
    await tester.pumpAndSettle();

    expect(generator.callCount, 2);
    expect(find.text('生活常用语'), findsOneWidget);
  });

  testWidgets('unsupported images use an accessible theme icon fallback', (
    tester,
  ) async {
    final entry = _entry(term: 'hello', meaning: '你好');
    final repository = _MemoryRepository([entry]);
    final imageGenerator = _ImageGenerator(
      capability: ReviewAIImageCapability.unsupported,
    );
    final feedback = <ReviewFeedback>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ReviewDeck(
            items: [ReviewQueueItem(entry: entry)],
            contentService: ReviewContentService(
              repository: repository,
              generator: _FailingThenSuccessfulGenerator(),
              now: () => DateTime.utc(2026, 7, 20, 13),
            ),
            imageService: ReviewImageService(
              repository: repository,
              generator: imageGenerator,
              now: () => DateTime.utc(2026, 7, 20, 13),
            ),
            onFeedback: (entry, value) async {
              feedback.add(value);
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '记忆插图，当前使用主题图标',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('retry-review-image')), findsNothing);
    expect(imageGenerator.requests, isEmpty);
    expect(find.byKey(const ValueKey('feedback-forgotten')), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-fuzzy')), findsOneWidget);
    expect(find.byKey(const ValueKey('feedback-remembered')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('feedback-forgotten')));
    await tester.pumpAndSettle();
    expect(feedback, [ReviewFeedback.forgotten]);
  });

  testWidgets('supported image is marked as AI generated', (tester) async {
    final entry = _entry(term: 'hello', meaning: '你好');
    final repository = _MemoryRepository([entry]);
    final imageGenerator = _ImageGenerator();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ReviewCard(
            entry: entry,
            contentService: ReviewContentService(
              repository: repository,
              generator: _FailingThenSuccessfulGenerator(),
              now: () => DateTime.utc(2026, 7, 20, 13),
            ),
            imageService: ReviewImageService(
              repository: repository,
              generator: imageGenerator,
              now: () => DateTime.utc(2026, 7, 20, 13),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI 生成插图'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'AI 生成的记忆插图',
      ),
      findsOneWidget,
    );
    expect(imageGenerator.requests, hasLength(1));
  });
}

class _ImageGenerator implements ReviewImageGenerator {
  _ImageGenerator({this.capability = ReviewAIImageCapability.supported});

  @override
  final ReviewAIImageCapability capability;
  final requests = <ReviewAIImageRequest>[];

  @override
  String get cacheNamespace => 'ui-image|model-1';

  @override
  Future<void> cancelActiveRequest() async {}

  @override
  Future<ReviewAIImageResponse> generate(ReviewAIImageRequest request) async {
    requests.add(request);
    return ReviewAIImageResponse(
      mediaType: 'image/png',
      bytes: base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwC'
        'AAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  }
}

class _ControlledGenerator implements ReviewTextContentGenerator {
  final requests = <ReviewAITextContentRequest>[];
  final _responses = <Completer<ReviewAITextContentResponse>>[];

  @override
  String get cacheNamespace => 'ui-content|model-1';

  @override
  Future<void> cancelActiveRequest() async {}

  @override
  Future<ReviewAITextContentResponse> generate(
    ReviewAITextContentRequest request,
  ) {
    requests.add(request);
    final response = Completer<ReviewAITextContentResponse>();
    _responses.add(response);
    return response.future;
  }

  void completeNext() {
    _responses
        .firstWhere((response) => !response.isCompleted)
        .complete(_response());
  }
}

class _FailingThenSuccessfulGenerator implements ReviewTextContentGenerator {
  int callCount = 0;

  @override
  String get cacheNamespace => 'ui-failure|model-1';

  @override
  Future<void> cancelActiveRequest() async {}

  @override
  Future<ReviewAITextContentResponse> generate(
    ReviewAITextContentRequest request,
  ) async {
    callCount++;
    if (callCount == 1) {
      throw StateError('/private/path contains user input');
    }
    return _response();
  }
}

ReviewAITextContentResponse _response() {
  return ReviewAITextContentResponse(
    everydayUsages: [
      ReviewAIEverydayUsage(
        situation: '初次见面',
        original: 'A small game helped break the ice.',
        translation: '一个小游戏帮助大家打破了僵局。',
      ),
    ],
    fictionalDialogue: ReviewAIFictionalDialogue(
      dialogue: 'We should break the ice first.',
      translation: '我们应该先活跃一下气氛。',
    ),
  );
}

class _MemoryRepository implements ReviewRepository {
  _MemoryRepository(Iterable<ReviewEntry> entries)
    : entries = {for (final entry in entries) entry.identity: entry};

  final Map<ReviewIdentity, ReviewEntry> entries;
  final Map<String, ReviewDerivedContent> _derived = {};

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

ReviewEntry _entry({
  required String term,
  required String meaning,
  String? partOfSpeech,
  String? pronunciation,
  Iterable<String> secondaryMeanings = const [],
}) {
  final identity = ReviewIdentity.create(
    correctedTerm: term,
    actualSourceLanguage: TranslationSourceLanguage.en,
    targetLanguage: TranslationSourceLanguage.zh,
  );
  return ReviewEntry.firstTranslation(
    identity: identity,
    originalAlias: term,
    translatedAt: DateTime.utc(2026, 7, 18),
    content: ReviewEntryContent(
      sourceText: term,
      translationText: meaning,
      primaryMeaning: meaning,
      partOfSpeech: partOfSpeech,
      pronunciation: pronunciation,
      secondaryMeanings: secondaryMeanings,
    ),
  );
}
