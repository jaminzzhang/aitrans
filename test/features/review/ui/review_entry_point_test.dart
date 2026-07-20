import 'dart:async';

import 'package:aitrans/app.dart';
import 'package:aitrans/core/ai/review_ai_models.dart';
import 'package:aitrans/core/ai/ai_provider.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/data/review_preferences_store.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/logic/review_providers.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/review/services/review_ranker.dart';
import 'package:aitrans/features/review/services/review_content_service.dart';
import 'package:aitrans/features/translate/models/translation_presentation.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:aitrans/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens the full-screen review page from the mobile toolbar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.iOS),
          home: const AppShell(),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('review-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-page')), findsOneWidget);
    expect(find.text('今日复习'), findsOneWidget);
    expect(find.text('历史记录'), findsOneWidget);
  });

  testWidgets('shows the local total due count in the toolbar badge', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final repository = _MemoryReviewRepository([
      _entry(createdAt: now.subtract(const Duration(days: 2))),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [reviewRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('review-badge')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('review-badge')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('reentering today review reuses the ranked group snapshot', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final repository = _MemoryReviewRepository([
      _entry(createdAt: now.subtract(const Duration(days: 2))),
    ]);
    final ranker = _CountingReviewRanker();
    final contentGenerator = _ImmediateReviewTextGenerator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repository),
          reviewRankerProvider.overrideWith((ref, config) => ranker),
          reviewTextContentGeneratorProvider.overrideWith(
            (ref, config) => contentGenerator,
          ),
          reviewPreferencesStoreProvider.overrideWithValue(
            MemoryReviewPreferencesStore(
              const ReviewPreferences(
                captureEnabled: true,
                privacyNoticeAcknowledged: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsOneWidget);
    expect(ranker.requestCount, 1);
  });

  testWidgets('today review renders the current progressive learning card', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final repository = _MemoryReviewRepository([
      _entry(
        term: 'break the ice',
        meaning: '打破僵局',
        createdAt: now.subtract(const Duration(days: 2)),
        partOfSpeech: 'idiom',
      ),
    ]);
    final generator = _ImmediateReviewTextGenerator();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repository),
          reviewRankerProvider.overrideWith(
            (ref, config) => _CountingReviewRanker(),
          ),
          reviewTextContentGeneratorProvider.overrideWith(
            (ref, config) => generator,
          ),
          reviewPreferencesStoreProvider.overrideWithValue(
            MemoryReviewPreferencesStore(
              const ReviewPreferences(
                captureEnabled: true,
                privacyNoticeAcknowledged: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();

    expect(find.text('break the ice'), findsOneWidget);
    expect(find.text('idiom'), findsOneWidget);
    expect(find.text('生活常用语'), findsOneWidget);
    expect(find.text('影视化场景对白'), findsOneWidget);
    expect(generator.callCount, 1);
  });

  testWidgets(
    'feedback completes a group and forgotten is due in ten minutes',
    (tester) async {
      var now = DateTime.utc(2026, 7, 20, 12);
      final repository = _MemoryReviewRepository([
        _entry(createdAt: now.subtract(const Duration(days: 2))),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(repository),
            reviewSchedulerProvider.overrideWithValue(
              ReviewScheduler(now: () => now),
            ),
            reviewRankerProvider.overrideWith(
              (ref, config) => _CountingReviewRanker(),
            ),
            reviewTextContentGeneratorProvider.overrideWith(
              (ref, config) => _ImmediateReviewTextGenerator(),
            ),
            reviewPreferencesStoreProvider.overrideWithValue(
              MemoryReviewPreferencesStore(
                const ReviewPreferences(
                  captureEnabled: true,
                  privacyNoticeAcknowledged: true,
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('review-button')));
      await tester.pumpAndSettle();

      expect(find.text('hello'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics && widget.properties.label == '记忆插图，当前使用主题图标',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('feedback-forgotten')));
      await tester.pumpAndSettle();

      expect(find.text('本组复习完成'), findsOneWidget);
      expect(find.byKey(const ValueKey('next-review-group')), findsOneWidget);
      expect(repository.entries.single.forgetCount, 1);
      expect(
        repository.entries.single.nextReviewAt,
        now.add(const Duration(minutes: 10)),
      );
      expect(repository.entries.single.appliedFeedbackEventIds, hasLength(1));

      now = now.add(const Duration(minutes: 10));
      await tester.tap(find.byKey(const ValueKey('next-review-group')));
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);
    },
  );

  testWidgets('shows the capture policy once before using review history', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(
            _MemoryReviewRepository([]),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();

    expect(find.text('关于复习记录'), findsOneWidget);
    expect(find.textContaining('本机加密保存'), findsOneWidget);
    expect(find.textContaining('长句不会记录'), findsOneWidget);
    expect(find.textContaining('必要摘要'), findsOneWidget);
    await tester.tap(find.text('了解并继续'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();

    expect(find.text('关于复习记录'), findsNothing);
  });

  testWidgets('confirms a single deletion and updates history and badge', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final repository = _MemoryReviewRepository([
      _entry(createdAt: now.subtract(const Duration(days: 2))),
    ]);
    final ranker = _CountingReviewRanker();
    final contentGenerator = _ImmediateReviewTextGenerator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repository),
          reviewRankerProvider.overrideWith((ref, config) => ranker),
          reviewTextContentGeneratorProvider.overrideWith(
            (ref, config) => contentGenerator,
          ),
          reviewPreferencesStoreProvider.overrideWithValue(
            MemoryReviewPreferencesStore(
              const ReviewPreferences(
                captureEnabled: true,
                privacyNoticeAcknowledged: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-badge')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史记录'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-review-entry')));
    await tester.pumpAndSettle();

    expect(find.text('删除这条记录？'), findsOneWidget);
    expect(repository.entries, hasLength(1));
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    expect(repository.entries, isEmpty);
    expect(find.text('hello'), findsNothing);
    expect(find.text('翻译过的单词和短语会显示在这里'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-badge')), findsNothing);
    expect(ranker.cancelCount, 1);
    expect(contentGenerator.cancelCount, 1);
  });

  testWidgets('requires confirmation before clearing all review history', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final repository = _MemoryReviewRepository([
      _entry(createdAt: now.subtract(const Duration(days: 2))),
      _entry(
        term: 'world',
        meaning: '世界',
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ]);
    final ranker = _CountingReviewRanker();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repository),
          reviewRankerProvider.overrideWith((ref, config) => ranker),
          reviewPreferencesStoreProvider.overrideWithValue(
            MemoryReviewPreferencesStore(
              const ReviewPreferences(
                captureEnabled: true,
                privacyNoticeAcknowledged: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史记录'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('clear-review-history')));
    await tester.pumpAndSettle();
    expect(find.text('清空全部复习记录？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(repository.clearCount, 0);
    expect(repository.entries, hasLength(2));

    await tester.tap(find.byKey(const ValueKey('clear-review-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清空'));
    await tester.pumpAndSettle();

    expect(repository.clearCount, 1);
    expect(repository.entries, isEmpty);
    expect(find.text('翻译过的单词和短语会显示在这里'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-badge')), findsNothing);
    expect(ranker.cancelCount, 1);
  });

  testWidgets(
    'securely rebuilds unavailable review storage after confirmation',
    (tester) async {
      final repository = _MemoryReviewRepository(
        [],
        repositoryState: ReviewRepositoryState.unavailable,
        resetRecovers: true,
      );
      final preferencesStore = MemoryReviewPreferencesStore(
        const ReviewPreferences(
          captureEnabled: true,
          privacyNoticeAcknowledged: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(repository),
            reviewPreferencesStoreProvider.overrideWithValue(preferencesStore),
          ],
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
        listen: false,
      );
      expect(container.read(reviewCaptureEnabledProvider), isFalse);

      await tester.tap(find.byKey(const ValueKey('review-button')));
      await tester.pumpAndSettle();
      expect(find.text('复习记录暂时不可用'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('rebuild-review-history')));
      await tester.pumpAndSettle();

      expect(find.text('安全清空并重建？'), findsOneWidget);
      await tester.tap(find.text('确认重建'));
      await tester.pumpAndSettle();

      expect(repository.clearCount, 1);
      expect(repository.state, ReviewRepositoryState.ready);
      expect(find.text('今天没有需要复习的内容'), findsOneWidget);
      expect(container.read(reviewCaptureEnabledProvider), isTrue);
    },
  );

  testWidgets('redacts storage details when secure rebuild fails', (
    tester,
  ) async {
    final repository = _MemoryReviewRepository(
      [],
      repositoryState: ReviewRepositoryState.unavailable,
      resetError: StateError('/private/path contained private-user-term'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repository),
          reviewPreferencesStoreProvider.overrideWithValue(
            MemoryReviewPreferencesStore(
              const ReviewPreferences(
                captureEnabled: true,
                privacyNoticeAcknowledged: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rebuild-review-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认重建'));
    await tester.pumpAndSettle();

    expect(find.text('安全存储仍不可用，请稍后重试'), findsOneWidget);
    expect(find.textContaining('/private/path'), findsNothing);
    expect(find.textContaining('private-user-term'), findsNothing);
    expect(repository.state, ReviewRepositoryState.unavailable);
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.android]) {
    testWidgets('opens a full-screen review route on ${platform.name}', (
      tester,
    ) async {
      final size = platform == TargetPlatform.macOS
          ? const Size(800, 450)
          : const Size(390, 844);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            reviewRepositoryProvider.overrideWithValue(
              _MemoryReviewRepository([]),
            ),
            reviewPreferencesStoreProvider.overrideWithValue(
              MemoryReviewPreferencesStore(
                const ReviewPreferences(
                  captureEnabled: true,
                  privacyNoticeAcknowledged: true,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: platform),
            home: const AppShell(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (platform == TargetPlatform.android) {
        expect(
          tester.getSize(find.byKey(const ValueKey('review-button'))).height,
          greaterThanOrEqualTo(48),
        );
      }
      await tester.tap(find.byKey(const ValueKey('review-button')));
      await tester.pumpAndSettle();

      expect(tester.getSize(find.byKey(const ValueKey('review-page'))), size);
      expect(find.text('今日复习'), findsOneWidget);
      expect(find.text('历史记录'), findsOneWidget);
    });
  }

  testWidgets('returning from review keeps the translation input and result', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiProviderProvider.overrideWithValue(_TranslationAIProvider()),
          reviewRepositoryProvider.overrideWithValue(
            _MemoryReviewRepository([]),
          ),
          reviewPreferencesStoreProvider.overrideWithValue(
            MemoryReviewPreferencesStore(
              const ReviewPreferences(
                captureEnabled: false,
                privacyNoticeAcknowledged: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'keep this input');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
      listen: false,
    );
    container
        .read(translateControllerProvider.notifier)
        .translateNow('keep this input');
    await tester.pumpAndSettle();
    expect(find.text('保留的译文'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.text('keep this input'), findsOneWidget);
    expect(find.text('保留的译文'), findsOneWidget);
  });

  testWidgets('a late ranking result cannot revive a deleted history entry', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    final repository = _MemoryReviewRepository([
      _entry(createdAt: now.subtract(const Duration(days: 2))),
    ]);
    final ranker = _DelayedReviewRanker();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reviewRepositoryProvider.overrideWithValue(repository),
          reviewRankerProvider.overrideWith((ref, config) => ranker),
          reviewPreferencesStoreProvider.overrideWithValue(
            MemoryReviewPreferencesStore(
              const ReviewPreferences(
                captureEnabled: true,
                privacyNoticeAcknowledged: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('历史记录'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('delete-review-entry')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();

    ranker.complete();
    await tester.pumpAndSettle();

    expect(repository.entries, isEmpty);
    expect(find.text('hello'), findsNothing);
    expect(find.text('翻译过的单词和短语会显示在这里'), findsOneWidget);
  });
}

class _TranslationAIProvider extends AIProvider {
  @override
  String get name => 'translation-test';

  @override
  Future<bool> testConnection() async => true;

  @override
  Stream<TranslationResult> translate({
    required String text,
    String from = 'auto',
    String to = 'zh',
  }) {
    return Stream.fromIterable([
      TranslationResult(text: '保留的译文', isComplete: false),
      TranslationResult(text: '', isComplete: true),
    ]);
  }

  @override
  Stream<List<Example>> getExamples(String word) => const Stream.empty();

  @override
  Stream<List<MovieQuote>> getMovieQuotes(String word) => const Stream.empty();

  @override
  Stream<List<ExamItem>> getExamItems(String word) => const Stream.empty();
}

class _DelayedReviewRanker implements ReviewRanker {
  final _completer = Completer<ReviewAIRankResponse>();
  ReviewAIRankRequest? _request;

  @override
  String get cacheNamespace => 'test/delayed-ranker';

  @override
  Future<void> cancelActiveRequest() async {}

  @override
  Future<ReviewAIRankResponse> rank(ReviewAIRankRequest request) {
    _request = request;
    return _completer.future;
  }

  void complete() {
    final request = _request!;
    _completer.complete(
      ReviewAIRankResponse(
        rankedItems: request.candidates
            .take(10)
            .map(
              (candidate) =>
                  ReviewAIRankedItem(id: candidate.id, reason: 'late result'),
            ),
      ),
    );
  }
}

class _CountingReviewRanker implements ReviewRanker {
  int requestCount = 0;
  int cancelCount = 0;

  @override
  String get cacheNamespace => 'test/ranker';

  @override
  Future<void> cancelActiveRequest() async {
    cancelCount++;
  }

  @override
  Future<ReviewAIRankResponse> rank(ReviewAIRankRequest request) async {
    requestCount++;
    return ReviewAIRankResponse(
      rankedItems: request.candidates
          .take(10)
          .map(
            (candidate) =>
                ReviewAIRankedItem(id: candidate.id, reason: '最近容易忘记'),
          ),
    );
  }
}

class _ImmediateReviewTextGenerator implements ReviewTextContentGenerator {
  int callCount = 0;
  int cancelCount = 0;

  @override
  String get cacheNamespace => 'entry-point-content|model-1';

  @override
  Future<void> cancelActiveRequest() async {
    cancelCount++;
  }

  @override
  Future<ReviewAITextContentResponse> generate(
    ReviewAITextContentRequest request,
  ) async {
    callCount++;
    return ReviewAITextContentResponse(
      everydayUsages: [
        ReviewAIEverydayUsage(
          situation: '初次见面',
          original: 'A game can break the ice.',
          translation: '游戏可以帮助大家打破僵局。',
        ),
      ],
      fictionalDialogue: ReviewAIFictionalDialogue(
        dialogue: 'We need to break the ice.',
        translation: '我们需要打破僵局。',
      ),
    );
  }
}

class _MemoryReviewRepository implements ReviewRepository {
  _MemoryReviewRepository(
    this.entries, {
    this.repositoryState = ReviewRepositoryState.ready,
    this.resetRecovers = false,
    this.resetError,
  });

  final List<ReviewEntry> entries;
  final Map<String, ReviewDerivedContent> _derived = {};
  ReviewRepositoryState repositoryState;
  final bool resetRecovers;
  final Object? resetError;
  int clearCount = 0;

  @override
  ReviewRepositoryState get state => repositoryState;

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
    clearCount++;
    if (resetError case final error?) throw error;
    entries.clear();
    _derived.clear();
    if (resetRecovers) repositoryState = ReviewRepositoryState.ready;
  }

  @override
  Future<void> delete(ReviewIdentity identity) async {
    entries.removeWhere((entry) => entry.identity == identity);
    _derived.removeWhere((_, value) => value.identity == identity);
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
  }) async => _derived['${identity.toJson()}|$contentId'];

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
    _derived['${identity.toJson()}|$contentId'] = ReviewDerivedContent(
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
  }) async => throw UnsupportedError('not used by this test');
}

ReviewEntry _entry({
  String term = 'hello',
  String meaning = '你好',
  String? partOfSpeech,
  required DateTime createdAt,
}) {
  final identity = ReviewIdentity.create(
    correctedTerm: term,
    actualSourceLanguage: TranslationSourceLanguage.en,
    targetLanguage: TranslationSourceLanguage.zh,
  );
  return ReviewEntry.firstTranslation(
    identity: identity,
    originalAlias: term,
    translatedAt: createdAt,
    content: ReviewEntryContent(
      sourceText: term,
      translationText: meaning,
      primaryMeaning: meaning,
      partOfSpeech: partOfSpeech,
      secondaryMeanings: const [],
    ),
  );
}
