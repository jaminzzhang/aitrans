import 'package:aitrans/core/ai/provider_factory.dart';
import 'package:aitrans/core/config/ai_config.dart';
import 'package:aitrans/core/config/settings_repository.dart';
import 'package:aitrans/core/platform/menu_bar_preference_service.dart';
import 'package:aitrans/features/settings/ui/settings_page.dart';
import 'package:aitrans/features/review/data/review_preferences_store.dart';
import 'package:aitrans/features/review/data/review_repository.dart';
import 'package:aitrans/features/review/domain/review_identity.dart';
import 'package:aitrans/features/review/domain/review_feedback.dart';
import 'package:aitrans/features/review/domain/review_scheduler.dart';
import 'package:aitrans/features/review/logic/review_providers.dart';
import 'package:aitrans/features/review/models/review_entry.dart';
import 'package:aitrans/features/translate/logic/translate_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('selects Qwen and shows its endpoint and model defaults', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          _UnusedSettingsRepository(),
        ),
        menuBarPreferenceServiceProvider.overrideWithValue(
          _UnsupportedMenuBarPreferenceService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );

    await tester.tap(find.byType(DropdownButton<ProviderType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qwen').last);
    await tester.pumpAndSettle();

    expect(container.read(aiConfigProvider).providerType, ProviderType.ollama);
    expect(
      find.text('https://dashscope.aliyuncs.com/compatible-mode/v1'),
      findsOneWidget,
    );
    expect(find.text('qwen-plus'), findsOneWidget);
  });

  testWidgets('turns off review capture without deleting existing history', (
    tester,
  ) async {
    final preferencesStore = MemoryReviewPreferencesStore(
      const ReviewPreferences(
        captureEnabled: true,
        privacyNoticeAcknowledged: true,
      ),
    );
    final repository = _ReadyReviewRepository();
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          _UnusedSettingsRepository(),
        ),
        menuBarPreferenceServiceProvider.overrideWithValue(
          _UnsupportedMenuBarPreferenceService(),
        ),
        reviewRepositoryProvider.overrideWithValue(repository),
        reviewPreferencesStoreProvider.overrideWithValue(preferencesStore),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );
    await tester.pumpAndSettle();

    final captureSwitch = find.byKey(const ValueKey('review-capture-switch'));
    expect(tester.widget<Switch>(captureSwitch).value, isTrue);
    await tester.tap(captureSwitch);
    await tester.pumpAndSettle();

    expect(container.read(reviewCaptureEnabledProvider), isFalse);
    expect((await preferencesStore.load()).captureEnabled, isFalse);
    expect(repository.clearCount, 0);
  });

  testWidgets('redacts review preference write failures and pauses capture', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          _UnusedSettingsRepository(),
        ),
        menuBarPreferenceServiceProvider.overrideWithValue(
          _UnsupportedMenuBarPreferenceService(),
        ),
        reviewRepositoryProvider.overrideWithValue(_ReadyReviewRepository()),
        reviewPreferencesStoreProvider.overrideWithValue(
          _FailingReviewPreferencesStore(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: SettingsSheet())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('review-capture-switch')));
    await tester.pumpAndSettle();

    expect(find.text('复习设置无法保存，自动记录已暂停'), findsOneWidget);
    expect(find.textContaining('/private/preferences'), findsNothing);
    expect(find.textContaining('private-user-term'), findsNothing);
    expect(container.read(reviewCaptureEnabledProvider), isFalse);
  });
}

class _UnusedSettingsRepository implements SettingsRepository {
  @override
  Future<AIConfig> load() async => AIConfig(providerType: ProviderType.ollama);

  @override
  Future<AIConfig> loadProviderDraft(ProviderType providerType) async {
    return AIConfig(providerType: providerType);
  }

  @override
  Future<void> save(AIConfig config) async {}

  @override
  Future<void> resetCredentials() async {}
}

class _UnsupportedMenuBarPreferenceService implements MenuBarPreferenceService {
  @override
  bool get isSupported => false;

  @override
  Future<bool> getVisibility() => throw UnsupportedError('unsupported');

  @override
  Future<void> setVisibility(bool visible) =>
      throw UnsupportedError('unsupported');
}

class _ReadyReviewRepository implements ReviewRepository {
  int clearCount = 0;

  @override
  ReviewRepositoryState get state => ReviewRepositoryState.ready;

  @override
  Future<ReviewEntry?> applyFeedback({
    required ReviewIdentity identity,
    required ReviewFeedbackEvent event,
    required ReviewScheduler scheduler,
  }) => throw UnsupportedError('not used');

  @override
  Future<List<ReviewEntry>> all() async => const [];

  @override
  Future<void> clearAndReset() async {
    clearCount++;
  }

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

  @override
  Future<ReviewEntry> recordTranslation({
    required ReviewIdentity identity,
    required String originalAlias,
    required DateTime translatedAt,
    required ReviewEntryContent content,
  }) async => throw UnsupportedError('not used by this test');
}

class _FailingReviewPreferencesStore implements ReviewPreferencesStore {
  @override
  Future<ReviewPreferences> load() async {
    return const ReviewPreferences(
      captureEnabled: true,
      privacyNoticeAcknowledged: true,
    );
  }

  @override
  Future<void> save(ReviewPreferences preferences) {
    throw StateError('/private/preferences contained private-user-term');
  }
}
